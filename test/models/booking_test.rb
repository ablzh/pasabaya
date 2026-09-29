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
end
