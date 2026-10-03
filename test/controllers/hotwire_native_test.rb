require "test_helper"

class HotwireNativeTest < ActionDispatch::IntegrationTest
  NATIVE_HEADERS = { "HTTP_USER_AGENT" => "Mozilla/5.0 Hotwire Native iOS" }.freeze

  test "public configurations define versioned tabs and modal navigation" do
    %w[ios android].each do |platform|
      get "/configurations/#{platform}_v1.json"
      assert_response :success
      assert_equal "application/json", response.media_type
      assert_equal "public, no-cache, must-revalidate", response.headers["Cache-Control"]
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

  test "configuration endpoints mandate revalidation while asset caching remains far-future" do
    get "/configurations/ios_v1.json"
    assert_response :success
    assert_equal "public, no-cache, must-revalidate", response.headers["Cache-Control"]
    assert response.headers["Last-Modified"].present?
    assert response.headers["ETag"].present?

    get "/configurations/android_v1.json"
    assert_response :success
    assert_equal "public, no-cache, must-revalidate", response.headers["Cache-Control"]

    # Verify static assets inherit configured server caching rather than revalidation
    get "/icon.png"
    assert_response :success
    assert_equal Rails.application.config.public_file_server.headers["cache-control"], response.headers["Cache-Control"]
  end

  test "production-equivalent configuration requests use mandatory revalidation while asset caching remains far-future" do
    prod_handler = ActionDispatch::FileHandler.new(
      Rails.public_path.to_s,
      headers: { "cache-control" => "public, max-age=#{1.year.to_i}" }
    )
    middleware = Middleware::NativeConfigurationCacheControl.new(prod_handler)
    session = ActionDispatch::Integration::Session.new(middleware)

    session.get "/configurations/ios_v1.json"
    assert_equal 200, session.response.status
    assert_equal "public, no-cache, must-revalidate", session.response.headers["Cache-Control"]

    session.get "/icon.png"
    assert_equal 200, session.response.status
    assert_equal "public, max-age=#{1.year.to_i}", session.response.headers["Cache-Control"]
  end

  test "revised rules can be fetched at the same versioned URL via conditional revalidation" do
    get "/configurations/ios_v1.json"
    assert_response :success
    last_modified = response.headers["Last-Modified"]
    etag = response.headers["ETag"]

    # Conditional GET with If-Modified-Since returns 304 Not Modified
    get "/configurations/ios_v1.json", headers: { "HTTP_IF_MODIFIED_SINCE" => last_modified }
    assert_response :not_modified
    assert_equal "public, no-cache, must-revalidate", response.headers["Cache-Control"]

    # Conditional GET with If-None-Match returns 304 Not Modified
    get "/configurations/ios_v1.json", headers: { "HTTP_IF_NONE_MATCH" => etag }
    assert_response :not_modified
    assert_equal "public, no-cache, must-revalidate", response.headers["Cache-Control"]
  end

  test "native profile visibly identifies owner with full name even with no active posts" do
    user = users(:two)
    user.ride_posts.destroy_all
    sign_in_as(users(:one))

    get user_url(user), headers: NATIVE_HEADERS
    assert_response :success
    assert_select "title", text: "Profile"
    assert_select "h1[data-profile-name]", text: "#{user.first_name} #{user.last_name}"
    assert_select "h1.profile-name", text: "#{user.first_name} #{user.last_name}"
    assert_select "div", text: /No active ride offers or requests listed at the moment/
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
