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

    %i[banned_at booking_freeze_until deleted_at].each do |restriction|
      test "a stale ordinary offer rejects a request after its driver's #{restriction} changes" do
        stale_ride = RidePost.includes(:user).find(@ride.id)
        restriction_time = restriction == :booking_freeze_until ? 1.hour.from_now : Time.current
        User.find(@ride.user_id).update_columns(restriction => restriction_time)

        assert_no_difference [ "Booking.count", "Notification.count" ] do
          assert_no_enqueued_jobs only: BookingCutoffJob do
            error = assert_raises(ActiveRecord::RecordInvalid) do
              CreateService.call(ride_post: stale_ride, passenger: @passenger)
            end
            assert error.record.errors.of_kind?(:ride_post, :unavailable_ride)
          end
        end
      end
    end

    test "a hub offer rejects new requests as soon as its driver's membership expires" do
      community = communities(:one)
      driver_membership = community_memberships(:one)
      @ride.update!(visibility: :hub_only, community: community)
      CommunityMembership.create!(user: @passenger, community: community,
        institutional_email: "passenger@accenture.com", verified_at: Time.current, expires_at: 1.year.from_now)
      stale_ride = RidePost.includes(:user).find(@ride.id)
      driver_membership.update_columns(expires_at: Time.current)

      assert_no_difference [ "Booking.count", "Notification.count" ] do
        error = assert_raises(ActiveRecord::RecordInvalid) do
          CreateService.call(ride_post: stale_ride, passenger: @passenger)
        end
        assert error.record.errors.of_kind?(:ride_post, :unavailable_ride)
      end
    end

    test "an ordinary offer admits requests and acceptance when its driver's freeze expires" do
      thaw_at = 15.minutes.from_now.change(usec: 0)
      @ride.user.update!(booking_freeze_until: thaw_at)
      assert_raises(ActiveRecord::RecordInvalid) do
        CreateService.call(ride_post: @ride, passenger: @passenger)
      end

      travel_to thaw_at do
        booking = CreateService.call(ride_post: @ride, passenger: @passenger)
        assert booking.pending?
        assert AcceptService.call(booking, actor: @ride.user).accepted?
        assert_equal 2, @ride.reload.remaining_seats
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
