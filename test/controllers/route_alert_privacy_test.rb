require "test_helper"

class RouteAlertPrivacyTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

  test "revoked hub access hides previously delivered route details" do
    bookings(:one).destroy!
    passenger = users(:two)
    driver = users(:one)
    CommunityMembership.create!(user: driver, community: communities(:two), institutional_email: "driver@up.edu.ph", verified_at: Time.current)
    ride = ride_posts(:one)
    ride.update_columns(visibility: RidePost.visibilities[:hub_only], community_id: communities(:two).id)
    RouteSubscription.create!(user: passenger, origin_id: ride.origin_id, destination_id: ride.destination_id)
    RouteSubscriptions::MatchService.call(ride)
    notification = Notification.find_by!(event_name: "route.alert", recipient: passenger)
    notification.deliver!
    community_memberships(:two).update_columns(revoked_at: Time.current)
    sign_in_as(passenger)

    get notifications_url
    assert_select "#notification_#{notification.id}", count: 0
    assert_not_includes response.body, "matching ride from Manila"
    get notification_url(notification)
    assert_redirected_to ride_posts_url
    assert_no_emails { notification.deliver! }
    assert notification.reload.delivered?
  end
end
