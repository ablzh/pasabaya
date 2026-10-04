require "test_helper"

class RouteAlertDeliverySafetyTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  include ActionMailer::TestHelper

  setup do
    @ride = ride_posts(:one)
    @passenger = users(:two)
    @subscription = RouteSubscription.create!(user: @passenger, origin_id: @ride.origin_id, destination_id: @ride.destination_id)
    RouteSubscriptions::MatchService.call(@ride)
    @notification = Notification.find_by!(event_name: "route.alert", recipient: @passenger)
  end

  test "queued alert does not email or broadcast when seats are no longer available and can retry" do
    @ride.update_columns(remaining_seats: 0)
    stream = Turbo::StreamsChannel.send(:stream_name_from, [ @passenger, :notifications ])
    assert_no_emails do
      assert_no_broadcasts(stream) { @notification.deliver! }
    end
    assert @notification.reload.pending?
    @ride.update_columns(remaining_seats: 1)
    assert_emails(1) { @notification.deliver! }
    assert @notification.reload.delivered?
    assert_emails(0) { @notification.deliver! }
  end

  test "matching and delivery reject ineligible drivers" do
    @ride.user.update_columns(banned_at: Time.current)
    assert_no_emails { @notification.deliver! }
    assert @notification.reload.pending?
    fresh = RouteSubscription.create!(user: @passenger, origin_id: @ride.origin_id, destination_id: @ride.destination_id)
    assert_no_difference "Notification.count" do
      RouteSubscriptions::MatchService.call(@ride.reload)
    end
    assert fresh.reload.active?
  end

  test "queued delivery rechecks passenger eligibility" do
    @passenger.update_columns(booking_freeze_until: 1.day.from_now)
    assert_no_emails { @notification.deliver! }
    assert @notification.reload.pending?
  end

  test "queued delivery rechecks the restricted audience and driver hub eligibility" do
    hub = communities(:two)
    @ride.update_columns(visibility: RidePost.visibilities[:hub_only], community_id: hub.id)
    membership = CommunityMembership.create!(user: @ride.user, community: hub, institutional_email: "driver@up.edu.ph", verified_at: Time.current)
    community_memberships(:two).update_columns(revoked_at: Time.current)
    assert_no_emails { @notification.deliver! }
    assert @notification.reload.pending?
    community_memberships(:two).update_columns(revoked_at: nil)
    membership.update_columns(revoked_at: Time.current)
    assert_no_emails { @notification.deliver! }
    assert @notification.reload.pending?
  end
end
