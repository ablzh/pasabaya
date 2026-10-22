require "test_helper"

module RidePosts
  class CancelServiceTest < ActiveSupport::TestCase
    setup do
      @ride = ride_posts(:one)
      @passenger = users(:two)
      @driver = @ride.user
      @booking = bookings(:one)
    end

    test "driver canceling a ride cancels all active bookings and notifies passengers" do
      assert_difference("Notification.count", 1) do
        CancelService.call(@ride, actor: @driver)
      end

      assert @ride.reload.canceled?
      assert @booking.reload.canceled?

      notification = Notification.last
      assert_equal @passenger, notification.recipient
      assert_equal "ride.canceled", notification.event_name
      assert_equal [ @driver.id ], @ride.ride_post_dispatches.cancellation_refresh.sole.recipient_ids
    end

    test "rejects cancellation by non-driver actor" do
      assert_raises(CancelService::UnauthorizedError) do
        CancelService.call(@ride, actor: @passenger)
      end
    end

    test "a cable outage cannot roll back cancellation" do
      Bookings::AcceptService.call(@booking, actor: @driver)
      remaining_seats = @ride.reload.remaining_seats

      with_stubbed_method(Turbo::StreamsChannel, :broadcast_refresh_to, ->(*) { raise IOError, "Cable unavailable" }) do
        assert_nothing_raised { CancelService.call(@ride, actor: @driver) }
      end

      assert @ride.reload.canceled?
      assert @booking.reload.canceled?
      assert @booking.accepted_at
      assert_equal remaining_seats, @ride.remaining_seats
      assert Notification.exists?(delivery_key: "ride_canceled:#{@ride.id}:booking:#{@booking.id}")
    end

    test "a cancellation enqueue failure retains publication work without failing cancellation" do
      with_stubbed_method(RideCancellationBroadcastJob, :perform_later, ->(*) { raise IOError, "Queue unavailable" }) do
        assert_nothing_raised { CancelService.call(@ride, actor: @driver) }
      end

      assert @ride.reload.canceled?
      assert @booking.reload.canceled?
      dispatch = @ride.ride_post_dispatches.cancellation_refresh.sole
      assert_equal 1, dispatch.failure_count
      assert_equal "IOError", dispatch.last_error
    end

    test "driver can cancel hub trip even if driver community membership has expired" do
      community = communities(:one)
      driver_membership = community_memberships(:one)

      hub_ride = RidePost.create!(
        user: @driver,
        origin: locations(:one),
        destination: locations(:two),
        seats: 3,
        remaining_seats: 3,
        status: :active,
        visibility: :hub_only,
        community: community,
        departure_time: 3.days.from_now
      )

      driver_membership.update_columns(expires_at: 1.day.ago)

      assert_nothing_raised do
        CancelService.call(hub_ride, actor: @driver)
      end

      assert hub_ride.reload.canceled?
    end
  end
end
