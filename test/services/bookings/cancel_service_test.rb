require "test_helper"

module Bookings
  class CancelServiceTest < ActiveSupport::TestCase
    setup do
      @ride = ride_posts(:one)
      @passenger = users(:two)
      @driver = @ride.user
      @booking = bookings(:one)
    end

    test "canceling a pending booking does not alter remaining seats" do
      initial_seats = @ride.remaining_seats

      assert_difference("Notification.count", 1) do
        CancelService.call(@booking, actor: @passenger)
      end

      assert @booking.reload.canceled?
      assert_equal initial_seats, @ride.reload.remaining_seats
    end

    test "canceling an accepted booking restores 1 seat and reopens full ride" do
      @booking.update_columns(status: Booking.statuses[:accepted])
      @ride.update_columns(remaining_seats: 0, status: RidePost.statuses[:fulfilled])

      CancelService.call(@booking, actor: @passenger)

      assert_equal 1, @ride.reload.remaining_seats
      assert @ride.reload.active?
    end

    test "repeated cancellation is idempotent" do
      CancelService.call(@booking, actor: @passenger)

      assert_no_difference("Notification.count") do
        CancelService.call(@booking, actor: @passenger)
      end
    end

    test "rejects cancellation by stranger" do
      stranger = User.create!(
        email_address: "stranger@example.com",
        password: "password",
        first_name: "Random",
        last_name: "Stranger",
        facebook_profile_url: "https://facebook.com/stranger"
      )

      assert_raises(CancelService::UnauthorizedError) do
        CancelService.call(@booking, actor: stranger)
      end
    end
  end
end
