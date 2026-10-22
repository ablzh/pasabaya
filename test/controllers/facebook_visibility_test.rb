require "test_helper"

class FacebookVisibilityTest < ActionDispatch::IntegrationTest
  test "unlinked profiles expose no Facebook action and guests cannot retrieve links" do
    user = users(:one)
    sign_in_as(users(:two))
    user.update!(facebook_profile_url: nil)
    get user_url(user)
    assert_select "main a[href*='facebook.com']", count: 0
    user.update!(facebook_profile_url: "https://facebook.com/juan")
    sign_out
    get user_url(user)
    assert_redirected_to new_session_url
    assert_not_includes response.body, "https://facebook.com/juan"
  end

  test "members find Facebook only on profiles" do
    sign_in_as(users(:two))
    ride = ride_posts(:one)
    get ride_post_url(ride)
    assert_select "a[href='#{ride.user.facebook_profile_url}']", count: 0
    get ride_posts_url(origin_id: ride.origin_id)
    assert_select "a[href='#{ride.user.facebook_profile_url}']", count: 0
    get user_url(ride.user)
    assert_select "a[href='#{ride.user.facebook_profile_url}'][target='_blank'][rel='noopener noreferrer']"
  end
end
