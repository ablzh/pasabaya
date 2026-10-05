require "test_helper"

module Bookings
  class CreateServiceTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    setup do
      @ride = ride_posts(:one)
      @passenger = users(:two)
      bookings(:one).destroy!
    end

    test "creates a request with its notification and cutoff job" do
      booking = nil
      assert_enqueued_with(job: BookingCutoffJob, args: [ @ride.id ], at: @ride.booking_cutoff_at) do
        assert_difference [ "Booking.count", "Notification.count" ] do
          booking = CreateService.call(ride_post: @ride, passenger: @passenger, pickup_notes: "Near the station")
        end
      end
      assert booking.pending?
      assert_equal "Near the station", booking.pickup_notes
      notification = Notification.find_by!(notifiable: booking)
      assert_equal @ride.user_id, notification.recipient_id
      assert_equal @passenger.id, notification.actor_id
      assert_equal "booking.requested", notification.event_name
    end

    test "a request loaded before cancellation creates neither a booking nor notification" do
      stale_ride = RidePost.find(@ride.id)
      RidePosts::CancelService.call(@ride, actor: users(:one))

      assert_no_difference [ "Booking.count", "Notification.count" ] do
        assert_raises(ActiveRecord::RecordInvalid) do
          CreateService.call(ride_post: stale_ride, passenger: @passenger)
        end
      end
    end

    test "a notification failure rolls back the request without scheduling its cutoff" do
      assert_no_difference [ "Booking.count", "Notification.count" ] do
        assert_no_enqueued_jobs only: BookingCutoffJob do
          with_stubbed_method(Notification, :create!, ->(*) { raise ActiveRecord::RecordInvalid.new(Notification.new) }) do
            assert_raises(ActiveRecord::RecordInvalid) do
              CreateService.call(ride_post: @ride, passenger: @passenger)
            end
          end
        end
      end
    end
  end
end
