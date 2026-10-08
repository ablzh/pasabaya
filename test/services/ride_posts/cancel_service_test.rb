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
    end

    test "rejects cancellation by non-driver actor" do
      assert_raises(CancelService::UnauthorizedError) do
        CancelService.call(@ride, actor: @passenger)
      end
    end

    test "driver can cancel hub trip even if driver community membership has expired" do
      community = communities(:one)
      driver_membership = community_memberships(:one)

      hub_ride = RidePost.create!(
        user: @driver,
        origin: locations(:one),
        destination: locations(:two),
        post_type: :offering,
        seats: 3,
        remaining_seats: 3,
        status: :active,
        visibility: :hub_only,
        community: community,
        departure_time: 3.days.from_now,
        expected_arrival_at: 3.days.from_now + 2.hours
      )

      driver_membership.update_columns(expires_at: 1.day.ago)

      assert_nothing_raised do
        CancelService.call(hub_ride, actor: @driver)
      end

      assert hub_ride.reload.canceled?
    end
  end
end
