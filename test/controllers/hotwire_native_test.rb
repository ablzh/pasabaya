require "test_helper"

class HotwireNativeTest < ActionDispatch::IntegrationTest
  NATIVE_HEADERS = { "HTTP_USER_AGENT" => "Mozilla/5.0 Hotwire Native iOS" }.freeze

  test "public configurations define versioned tabs and modal navigation" do
    %w[ios android].each do |platform|
      get "/configurations/#{platform}_v1.json"
      assert_response :success
      assert_equal "application/json", response.media_type
      config = response.parsed_body
      assert_equal %w[/rides /trips /communities /settings/profile], config["settings"]["tabs"].pluck("path")

      %w[/session/new /sign_up /passwords/new /passwords/token/edit /rides/new?community_id=1 /rides/1-manila-to-makati/edit /rides/1/reviews/new].each do |path|
        properties = properties_for(config, path)
        assert_equal "modal", properties["context"], path
        assert_equal false, properties["pull_to_refresh_enabled"]
      end
      assert_equal "default", properties_for(config, "/rides/1?tab=chat")["context"]
      assert_equal "hotwire://fragment/web", properties_for(config, "/trips")["uri"] if platform == "android"
    end
  end

  test "native screens have one short title and preserve fallback actions" do
    get ride_posts_url, headers: NATIVE_HEADERS
    assert_response :success
    assert_select "title", count: 1, text: "Search"
    assert_select "html[data-hotwire-native='true'][lang='en']"
    assert_select "#native_navigation a[href='#{new_session_path}']"
    assert_includes response.headers["Vary"], "User-Agent"

    get ride_posts_url
    assert_select "html[data-hotwire-native='false']"
    assert_select "#native_navigation", count: 0
    assert_select "title", text: /Pasabaya/
  end

  test "My Trips always resolves the authenticated user and excludes private snapshots" do
    sign_in_as(users(:one))
    get trips_url(id: users(:two).id), headers: NATIVE_HEADERS
    assert_response :success
    assert_select "title", text: "My Trips"
    assert_select "h1", text: /Juan/
    assert_select "a[href='#{trips_path(tab: 'bookings')}']"
    assert_select "#native_navigation form[action='#{session_path}']"
    assert_select "meta[name='turbo-cache-control'][content='no-cache']"
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end

  test "native clients still need authorization for protected destinations" do
    get trips_url, headers: NATIVE_HEADERS
    assert_redirected_to new_session_path
    ride = ride_posts(:one)
    ride.update_columns(visibility: RidePost.visibilities[:hub_only], community_id: communities(:one).id)
    get ride_post_url(ride), headers: NATIVE_HEADERS
    assert_redirected_to ride_posts_path
  end

  test "sign in preserves the requested tab and issues a secure persistent cookie on HTTPS" do
    https!
    get trips_url(tab: "bookings"), headers: NATIVE_HEADERS
    post session_url, params: { email_address: users(:one).email_address, password: "password" }, headers: NATIVE_HEADERS
    assert_response :see_other
    assert_redirected_to trips_url(tab: "bookings")
    cookie = Array(response.headers["Set-Cookie"]).find { |value| value.start_with?("session_id=") }
    assert_match(/expires=/i, cookie)
    assert_match(/secure/i, cookie)
    assert_match(/httponly/i, cookie)
  end

  test "a revoked native session cannot reopen My Trips" do
    user = users(:one)
    sign_in_as(user)
    user.sessions.destroy_all
    get trips_url, headers: NATIVE_HEADERS
    assert_redirected_to new_session_path
  end

  test "HEAD destinations preserve the same sign in return path as GET" do
    head trips_url(tab: "bookings"), headers: NATIVE_HEADERS
    assert_redirected_to new_session_path
    post session_url, params: { email_address: users(:one).email_address, password: "password" }, headers: NATIVE_HEADERS
    assert_response :see_other
    assert_redirected_to trips_url(tab: "bookings")
  end

  test "native password changes retain errors and revoke only other sessions" do
    user = users(:one)
    sign_in_as(user)
    other_session = user.sessions.create!
    patch settings_password_url, params: { user: { password_challenge: "wrong", password: "new-password", password_confirmation: "new-password" } }, headers: NATIVE_HEADERS
    assert_response :unprocessable_content
    assert_select "title", text: "Account"
    assert_select "form[action='#{settings_password_path}']"
    assert user.reload.authenticate("password")
    assert Session.exists?(other_session.id)

    patch settings_password_url, params: { user: { password_challenge: "password", password: "new-password", password_confirmation: "new-password" } }, headers: NATIVE_HEADERS
    assert_response :see_other
    assert_redirected_to settings_profile_url
    assert user.reload.authenticate("new-password")
    assert_not Session.exists?(other_session.id)
    get trips_url, headers: NATIVE_HEADERS
    assert_response :success
  end

  test "native email changes retain invalid input and redirect after a valid request" do
    user = users(:one)
    original_email = user.email_address
    sign_in_as(user)
    patch settings_email_url, params: { user: { password_challenge: "password", unconfirmed_email: "invalid-email" } }, headers: NATIVE_HEADERS
    assert_response :unprocessable_content
    assert_select "title", text: "Account"
    assert_select "input[name='user[unconfirmed_email]'][value='invalid-email']"
    assert_nil user.reload.unconfirmed_email

    assert_enqueued_emails 1 do
      patch settings_email_url, params: { user: { password_challenge: "password", unconfirmed_email: "native-new@example.com" } }, headers: NATIVE_HEADERS
    end
    assert_response :see_other
    assert_redirected_to settings_profile_url
    assert_equal "native-new@example.com", user.reload.unconfirmed_email
    assert_equal original_email, user.email_address
  end

  private

  def properties_for(config, path)
    config["rules"].each_with_object({}) do |rule, properties|
      properties.merge!(rule["properties"]) if rule["patterns"].any? { |pattern| Regexp.new(pattern).match?(path) }
    end
  end
end
