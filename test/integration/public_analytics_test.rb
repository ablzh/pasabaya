require "test_helper"

class PublicAnalyticsTest < ActionDispatch::IntegrationTest
  test "production analytics uses only fixed public page identifiers" do
    origin_slug, destination_slug = Location.reorder(:id).limit(2).pluck(:slug)
    pages = {
      root_path => [ "/", "Home" ],
      privacy_path => [ "/privacy", "Privacy Policy" ],
      terms_path => [ "/terms", "Terms of Service" ],
      ride_posts_path => [ "/rides", "Ride Search" ],
      communities_path => [ "/communities", "Hubs" ],
      route_rides_path(origin_slug: origin_slug, destination_slug: destination_slug) => [ "/rides", "Ride Search" ]
    }

    with_stubbed_method(Rails.env, :production?, true) do
      pages.each do |path, (identifier, title)|
        get path, params: { token: "synthetic-private-token", email: "private@example.com" }
        assert_response :success
        assert_select "meta[name='analytics-page'][content='#{identifier}'][data-title='#{title}']", count: 1
        assert_select "script[src*='gc.zgo.at']", count: 0
      end
    end
  end

  test "authentication and detail pages never opt in to production analytics" do
    with_stubbed_method(Rails.env, :production?, true) do
      [ new_session_path, sign_up_path, new_password_path, edit_password_path(users(:one).password_reset_token),
        ride_post_path(ride_posts(:one)), community_path(communities(:one)) ].each do |path|
        get path
        assert_response :success
        assert_select "meta[name='analytics-page']", count: 0
        assert_select "script[src*='gc.zgo.at']", count: 0
      end

      sign_in_as(users(:one))
      [ settings_profile_path, trips_path, chats_path, notifications_path ].each do |path|
        get path
        assert_response :success
        assert_select "meta[name='analytics-page']", count: 0
      end
    end
  end

  test "an invalid password reset submission does not opt in to analytics" do
    with_stubbed_method(Rails.env, :production?, true) do
      put password_path(users(:one).password_reset_token), params: { password: "different", password_confirmation: "mismatch" }
      assert_response :unprocessable_content
      assert_select "meta[name='analytics-page']", count: 0
      assert_select "script[src*='gc.zgo.at']", count: 0
    end
  end

  test "development and native clients do not opt in to analytics" do
    get root_path
    assert_select "meta[name='analytics-page']", count: 0

    with_stubbed_method(Rails.env, :production?, true) do
      get root_path, headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 Hotwire Native iOS" }
      assert_response :success
      assert_select "meta[name='analytics-page']", count: 0
    end
  end
end
