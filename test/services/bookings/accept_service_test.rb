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

    test "rejects acceptance when hub driver community membership has expired" do
      community = communities(:one)
      driver_membership = community_memberships(:one)

      passenger_membership = CommunityMembership.create!(
        user: @passenger,
        community: community,
        institutional_email: "passenger_hub_test@accenture.com",
        verified_at: 1.month.ago,
        expires_at: 1.year.from_now
      )

      hub_ride = RidePost.create!(
        user: @driver,
        origin: locations(:one),
        destination: locations(:two),
        post_type: :offering,
        seats: 3,
        remaining_seats: 2,
        status: :active,
        visibility: :hub_only,
        community: community,
        departure_time: 3.days.from_now,
        expected_arrival_at: 3.days.from_now + 2.hours
      )

      pending_booking = Booking.create!(
        ride_post: hub_ride,
        passenger: @passenger,
        status: :pending
      )

      # Driver membership expires before cleanup runs
      driver_membership.update_columns(expires_at: 1.hour.ago)

      error = assert_raises(AcceptService::InvalidStateError) do
        AcceptService.call(pending_booking, actor: @driver)
      end

      assert_match(/Driver is no longer eligible/, error.message)
      assert pending_booking.reload.pending?
      assert_equal 2, hub_ride.reload.remaining_seats
    end

    test "rejects acceptance when driver is banned" do
      @driver.update_columns(banned_at: Time.current)

      error = assert_raises(AcceptService::InvalidStateError) do
        AcceptService.call(@booking, actor: @driver)
      end

      assert_match(/Driver is no longer eligible/, error.message)
      assert @booking.reload.pending?
    end
  end
end
