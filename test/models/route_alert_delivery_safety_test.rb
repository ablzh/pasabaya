require "test_helper"

class RouteAlertDeliverySafetyTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  include ActionMailer::TestHelper

  setup do
    @ride = ride_posts(:one)
    @passenger = users(:two)
    bookings(:one).destroy!
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

  test "queued alert waits until an edited ride matches the saved ordered route again" do
    original_destination = @ride.destination
    other_destination = Location.create!(name: "Other destination", slug: "other-destination", location_type: :city)
    @ride.update!(destination: other_destination)
    stream = Turbo::StreamsChannel.send(:stream_name_from, [ @passenger, :notifications ])

    assert_no_emails do
      assert_no_broadcasts(stream) { NotificationDeliveryJob.perform_now(@notification.id) }
    end
    assert @notification.reload.pending?

    @ride.update!(destination: original_destination)
    assert_emails(1) { NotificationDeliveryJob.perform_now(@notification.id) }
    assert @notification.reload.delivered?
  end

  test "a booking created after matching suppresses queued delivery until canceled" do
    booking = Booking.create!(ride_post: @ride, passenger: @passenger)
    stream = Turbo::StreamsChannel.send(:stream_name_from, [ @passenger, :notifications ])

    assert_no_emails do
      assert_no_broadcasts(stream) { NotificationDeliveryJob.perform_now(@notification.id) }
    end
    assert @notification.reload.pending?

    Bookings::AcceptService.call(booking, actor: @ride.user)
    assert_no_emails do
      assert_no_broadcasts(stream) { NotificationDeliveryJob.perform_now(@notification.id) }
    end
    assert @notification.reload.pending?

    Bookings::CancelService.call(booking, actor: @passenger)
    assert_emails(1) { NotificationDeliveryJob.perform_now(@notification.id) }
    assert @notification.reload.delivered?
    assert_emails(0) { NotificationDeliveryJob.perform_now(@notification.id) }
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

  test "queued dated alert does not deliver after a legitimate departure date edit" do
    subscription = RouteSubscription.create!(user: @passenger, origin_id: @ride.origin_id, destination_id: @ride.destination_id, departure_date: @ride.departure_date)
    RouteSubscriptions::MatchService.call(@ride)
    notification = Notification.find_by!(route_subscription: subscription)
    @ride.update!(departure_date: @ride.departure_date + 1, departure_choice: :morning, expected_arrival_at: nil)

    assert_no_emails { NotificationDeliveryJob.perform_now(notification.id) }
    assert notification.reload.pending?
  end

  test "queued ladies only search does not deliver an offer changed to a broader audience" do
    @ride.user.update!(gender: :female)
    @ride.update!(ladies_only: true)
    subscription = RouteSubscription.create!(user: @passenger, origin_id: @ride.origin_id, destination_id: @ride.destination_id, ladies_only: true)
    RouteSubscriptions::MatchService.call(@ride)
    notification = Notification.find_by!(route_subscription: subscription)
    @ride.update!(ladies_only: false)

    assert_no_emails { NotificationDeliveryJob.perform_now(notification.id) }
    assert notification.reload.pending?
  end

  test "queued hub search does not deliver an offer changed to the public board" do
    hub = communities(:two)
    CommunityMembership.create!(user: @ride.user, community: hub, institutional_email: "driver@up.edu.ph", verified_at: Time.current)
    @ride.update!(visibility: :hub_only, community: hub)
    subscription = RouteSubscription.create!(user: @passenger, origin_id: @ride.origin_id, destination_id: @ride.destination_id, community: hub)
    RouteSubscriptions::MatchService.call(@ride)
    notification = Notification.find_by!(route_subscription: subscription)
    @ride.update!(visibility: :public_ride, community: nil)

    assert_no_emails { NotificationDeliveryJob.perform_now(notification.id) }
    assert notification.reload.pending?
  end

  test "a genuine mail transport failure remains recoverable without recording a second event" do
    failing_transport = Class.new do
      def initialize(_settings); end

      def deliver!(_message)
        raise IOError, "Temporary mail transport failure"
      end
    end
    original_delivery_method = NotificationMailer.delivery_method
    begin
      NotificationMailer.delivery_method = failing_transport
      assert_raises(IOError) { @notification.deliver! }
    ensure
      NotificationMailer.delivery_method = original_delivery_method
    end
    assert @notification.reload.failed?

    assert_enqueued_with(job: NotificationDeliveryJob, args: [ @notification.id ]) { NotificationRecoveryJob.perform_now }
    assert_no_difference("Notification.count") do
      assert_emails(1) { NotificationDeliveryJob.perform_now(@notification.id) }
      assert_emails(0) { NotificationDeliveryJob.perform_now(@notification.id) }
    end
    assert @notification.reload.delivered?
  end

  test "retrying a realtime transport failure does not resend a successfully delivered email" do
    outage = ->(*) { raise IOError, "Temporary realtime transport failure" }
    assert_emails(1) do
      with_stubbed_method(ActionCable.server, :broadcast, outage) do
        assert_raises(IOError) { @notification.deliver! }
      end
    end
    assert @notification.reload.failed?

    assert_enqueued_with(job: NotificationDeliveryJob, args: [ @notification.id ]) { NotificationRecoveryJob.perform_now }
    stream = Turbo::StreamsChannel.send(:stream_name_from, [ @passenger, :notifications ])
    assert_no_emails do
      assert_broadcasts(stream, 3) { NotificationDeliveryJob.perform_now(@notification.id) }
    end
    assert @notification.reload.delivered?
    assert_no_emails { NotificationDeliveryJob.perform_now(@notification.id) }
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
