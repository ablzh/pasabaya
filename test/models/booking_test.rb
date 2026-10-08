require "test_helper"

class BookingTest < ActiveSupport::TestCase
  test "driver cannot request a seat on their own ride" do
    ride = ride_posts(:one)
    booking = Booking.new(ride_post: ride, passenger: ride.user)

    assert_not booking.valid?
    assert_includes booking.errors[:base], "Drivers cannot request seats on their own ride"
  end

  test "frozen user cannot request a seat" do
    ride = ride_posts(:one)
    passenger = users(:two)
    passenger.update_columns(booking_freeze_until: 3.days.from_now)

    booking = Booking.new(ride_post: ride, passenger: passenger)
    assert_not booking.valid?
    assert_includes booking.errors[:passenger], "is not eligible to request seats"
  end

  test "cannot book ride if ride is not bookable" do
    ride = ride_posts(:one)
    ride.update_columns(remaining_seats: 0, status: RidePost.statuses[:fulfilled])

    booking = Booking.new(ride_post: ride, passenger: users(:two))
    assert_not booking.valid?
    assert_includes booking.errors[:ride_post], "is not available for booking"
  end

  test "cannot have duplicate active bookings for the same passenger and ride" do
    existing = bookings(:one) # pending booking for ride :one and user :two
    duplicate = Booking.new(ride_post: existing.ride_post, passenger: existing.passenger)

    assert_not duplicate.save
  end

  test "cannot hard delete booking that retains historical review eligibility" do
    ride = ride_posts(:one)
    booking = bookings(:one)
    booking.update_columns(status: Booking.statuses[:accepted], accepted_at: 3.hours.ago)
    ride.update_columns(departure_time: 2.hours.ago, expected_arrival_at: 1.hour.ago)

    assert booking.historical_reviewable?
    assert_no_difference "Booking.count" do
      assert_not booking.destroy
    end
    assert_includes booking.errors[:base], "Cannot delete booking with historical participation. Records must be preserved for review eligibility."

    # Also after late cancellation
    booking.update_columns(status: Booking.statuses[:canceled], canceled_at: 1.hour.ago)
    assert booking.historical_reviewable?
    assert_not booking.destroy
  end

  test "can delete booking without historical participation" do
    booking = bookings(:one)
    assert_not booking.historical_reviewable?
    assert booking.destroy
  end
end
