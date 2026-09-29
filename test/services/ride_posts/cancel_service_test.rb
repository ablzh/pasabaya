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
  end
end
