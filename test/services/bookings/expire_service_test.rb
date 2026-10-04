# frozen_string_literal: true

require "test_helper"

module Bookings
  class ExpireServiceTest < ActiveSupport::TestCase
    setup do
      @driver = users(:one)
      @passenger = users(:two)
    end

    test "expires pending booking at exact departure cutoff and notifies passenger" do
      departure = 1.hour.from_now
      ride = RidePost.create!(
        user: @driver,
        origin: locations(:one),
        destination: locations(:two),
        post_type: :offering,
        seats: 3,
        remaining_seats: 3,
        departure_date: departure.to_date,
        departure_choice: :exact_time,
        departure_time: departure,
        status: :active
      )
      booking = Booking.create!(ride_post: ride, passenger: @passenger, status: :pending)

      # Before cutoff: should not expire
      ExpireService.call(booking)
      assert booking.reload.pending?

      # At/after cutoff: expires
      travel_to departure + 1.minute do
        assert_difference("Notification.count", 1) do
          ExpireService.call(booking)
        end

        assert booking.reload.expired?
        assert_equal 3, ride.reload.remaining_seats

        notif = Notification.last
        assert_equal @passenger, notif.recipient
        assert_equal "booking.expired", notif.event_name
        assert_equal "Your seat request expired without confirmation", notif.summary
      end
    end

    test "expires pending booking at approximate departure cutoff (end of day Manila)" do
      target_date = Date.current
      ride = RidePost.create!(
        user: @driver,
        origin: locations(:one),
        destination: locations(:two),
        post_type: :offering,
        seats: 3,
        remaining_seats: 3,
        departure_date: target_date,
        departure_choice: :morning,
        status: :active
      )
      booking = Booking.create!(ride_post: ride, passenger: @passenger, status: :pending)

      # During departure date (e.g. 14:00 PM, after morning window): still pending and bookable
      travel_to target_date.in_time_zone("Asia/Manila").change(hour: 14, min: 0) do
        ExpireService.call(booking)
        assert booking.reload.pending?
      end

      # After departure date ends (midnight + 1 second): expires
      travel_to (target_date + 1.day).in_time_zone("Asia/Manila").beginning_of_day + 1.second do
        ExpireService.call(ride)
        assert booking.reload.expired?
        assert_equal 3, ride.reload.remaining_seats
      end
    end

    test "does not modify accepted or declined bookings and does not change seat inventory" do
      departure = 1.hour.from_now
      other_user = User.create!(
        email_address: "other@example.com",
        password: "password",
        first_name: "Other",
        last_name: "User"
      )
      ride = RidePost.create!(
        user: @driver,
        origin: locations(:one),
        destination: locations(:two),
        post_type: :offering,
        seats: 3,
        remaining_seats: 2,
        departure_date: departure.to_date,
        departure_choice: :exact_time,
        departure_time: departure,
        status: :active
      )
      accepted = Booking.create!(ride_post: ride, passenger: @passenger, status: :accepted)
      declined = Booking.create!(ride_post: ride, passenger: other_user, status: :declined)

      travel_to departure + 10.minutes do
        ExpireService.call(ride)
        assert accepted.reload.accepted?
        assert declined.reload.declined?
        assert_equal 2, ride.reload.remaining_seats
      end
    end

    test "repeated processing is idempotent and creates no duplicate notifications" do
      departure = 1.hour.from_now
      ride = RidePost.create!(
        user: @driver,
        origin: locations(:one),
        destination: locations(:two),
        post_type: :offering,
        seats: 3,
        departure_date: departure.to_date,
        departure_choice: :exact_time,
        departure_time: departure,
        status: :active
      )
      booking = Booking.create!(ride_post: ride, passenger: @passenger, status: :pending)

      travel_to departure + 10.minutes do
        ExpireService.call(booking)
        assert booking.reload.expired?

        assert_no_difference("Notification.count") do
          ExpireService.call(booking)
          ExpireService.call(ride)
        end
      end
    end

    test "acceptance after cutoff fails and cannot race with expiry" do
      departure = 1.hour.from_now
      ride = RidePost.create!(
        user: @driver,
        origin: locations(:one),
        destination: locations(:two),
        post_type: :offering,
        seats: 3,
        departure_date: departure.to_date,
        departure_choice: :exact_time,
        departure_time: departure,
        status: :active
      )
      booking = Booking.create!(ride_post: ride, passenger: @passenger, status: :pending)

      travel_to departure + 5.minutes do
        # AcceptService refuses after cutoff
        error = assert_raises(AcceptService::InvalidStateError) do
          AcceptService.call(booking, actor: @driver)
        end
        assert_match(/Cannot accept bookings for rides in the past/, error.message)

        # Expiry succeeds cleanly
        ExpireService.call(booking)
        assert booking.reload.expired?
      end
    end
  end
end
