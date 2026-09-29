require "test_helper"

module Bookings
  class AcceptServiceTest < ActiveSupport::TestCase
    setup do
      @ride = ride_posts(:one)
      @passenger = users(:two)
      @driver = @ride.user
      @booking = bookings(:one)
    end

    test "driver accepting a pending booking decrements capacity and notifies passenger" do
      initial_seats = @ride.remaining_seats

      assert_difference("Notification.count", 1) do
        accepted_booking = AcceptService.call(@booking, actor: @driver)
        assert accepted_booking.accepted?
      end

      assert_equal initial_seats - 1, @ride.reload.remaining_seats

      notification = Notification.last
      assert_equal @passenger, notification.recipient
      assert_equal @driver, notification.actor
      assert_equal "booking.accepted", notification.event_name
    end

    test "marks ride fulfilled when remaining seats reach zero" do
      @ride.update_columns(remaining_seats: 1)

      AcceptService.call(@booking, actor: @driver)

      assert_equal 0, @ride.reload.remaining_seats
      assert @ride.fulfilled?
    end

    test "repeated acceptance is idempotent and does not decrement seats again" do
      AcceptService.call(@booking, actor: @driver)
      remaining_after_first = @ride.reload.remaining_seats

      assert_no_difference("Notification.count") do
        AcceptService.call(@booking, actor: @driver)
      end

      assert_equal remaining_after_first, @ride.reload.remaining_seats
    end

    test "rejects acceptance by non-driver actor" do
      assert_raises(AcceptService::UnauthorizedError) do
        AcceptService.call(@booking, actor: @passenger)
      end
    end

    test "raises CapacityError when no seats remain" do
      @ride.update_columns(remaining_seats: 0)

      assert_raises(AcceptService::CapacityError) do
        AcceptService.call(@booking, actor: @driver)
      end
    end

    test "competing accepts for final seat: only one succeeds" do
      @ride.update_columns(remaining_seats: 1)

      # Create a second passenger and booking
      other_user = User.create!(
        email_address: "other@example.com",
        password: "password",
        first_name: "Other",
        last_name: "Commuter",
        facebook_profile_url: "https://facebook.com/other"
      )

      # Bypass initial create check to simulate two simultaneous pending requests
      second_booking = Booking.new(ride_post: @ride, passenger: other_user, status: :pending)
      second_booking.save!(validate: false)

      # Accept first
      AcceptService.call(@booking, actor: @driver)
      assert_equal 0, @ride.reload.remaining_seats

      # Second accept must fail with CapacityError
      assert_raises(AcceptService::CapacityError) do
        AcceptService.call(second_booking, actor: @driver)
      end

      assert_equal 0, @ride.reload.remaining_seats
    end
  end
end
