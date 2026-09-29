require "test_helper"

class RidePostTest < ActiveSupport::TestCase
  test "invalid if departure time is in the past on creation or schedule change" do
    ride_post = ride_posts(:one)
    ride_post.departure_time = 1.hour.ago

    assert_not ride_post.valid?
    assert_includes ride_post.errors[:departure_time], "can't be in the past"
  end

  test "historical ride remains updateable if departure time is not changed" do
    ride = ride_posts(:one)
    ride.update_columns(departure_time: 2.days.ago, expected_arrival_at: 2.days.ago + 2.hours)

    ride.reload
    ride.notes = "Updated historical coordination notes"
    assert ride.valid?
    assert ride.save
  end

  test "cost sharing enforces mutual exclusion between free ride and toll/gas contribution" do
    ride = ride_posts(:one)
    ride.is_free_ride = true
    ride.share_tolls = true

    assert_not ride.valid?
    assert_includes ride.errors[:base], "Free rides cannot be combined with toll or gas sharing"

    ride.share_tolls = false
    ride.split_gas = true
    assert_not ride.valid?

    ride.split_gas = false
    assert ride.valid?
  end

  test "published offering requires arrival after departure and remaining seats" do
    ride = RidePost.new(
      user: users(:one),
      origin: locations(:one),
      destination: locations(:two),
      post_type: :offering,
      status: :active,
      seats: 3,
      departure_time: 1.day.from_now,
      expected_arrival_at: 1.day.from_now - 1.hour, # before departure
      remaining_seats: 3
    )
    assert_not ride.valid?
    assert_includes ride.errors[:expected_arrival_at], "must be after departure time"

    ride.expected_arrival_at = 1.day.from_now + 2.hours
    assert ride.valid?
  end

  test "locks attributes when accepted bookings exist" do
    ride = ride_posts(:one)
    booking = bookings(:one)
    booking.update_columns(status: Booking.statuses[:accepted])

    # Notes can still be updated
    ride.notes = "Pickup point updated"
    assert ride.valid?

    # Schedule cannot be updated
    ride.departure_time = 3.days.from_now
    assert_not ride.valid?
    assert_includes ride.errors[:base], "Cannot modify route, schedule, capacity, or audience while accepted bookings exist"
  end

  test "cannot manually modify remaining_seats while accepted bookings exist" do
    ride = ride_posts(:one)
    booking = bookings(:one)
    booking.update_columns(status: Booking.statuses[:accepted])
    ride.update_columns(remaining_seats: ride.seats - 1)

    # Driver attempts to reset remaining_seats back to full capacity
    ride.remaining_seats = ride.seats
    assert_not ride.valid?
    assert_includes ride.errors[:remaining_seats], "cannot exceed available capacity (2) while accepted bookings exist"
  end

  test "draft offers require ownership to view" do
    ride = ride_posts(:one)
    ride.update_columns(status: RidePost.statuses[:draft])

    driver = ride.user
    other_user = users(:two)

    assert ride.authorized_viewer?(driver)
    assert_not ride.authorized_viewer?(other_user)
    assert_not ride.authorized_viewer?(nil)
  end

  test "frozen driver can cancel their ride" do
    ride = ride_posts(:one)
    driver = ride.user
    driver.update_columns(booking_freeze_until: 7.days.from_now)

    assert driver.booking_frozen?
    assert_not driver.eligible_for_offering?

    # Canceling the ride should succeed without RecordInvalid
    assert_nothing_raised do
      RidePosts::CancelService.call(ride, actor: driver)
    end
    assert ride.reload.canceled?
  end

  test "passenger can cancel booking and restore seats even if driver is frozen" do
    ride = ride_posts(:one)
    driver = ride.user
    booking = bookings(:one)
    booking.update_columns(status: Booking.statuses[:accepted])
    ride.update_columns(remaining_seats: ride.seats - 1, status: RidePost.statuses[:fulfilled])

    # Driver becomes frozen
    driver.update_columns(booking_freeze_until: 7.days.from_now)

    # Passenger cancels booking
    assert_nothing_raised do
      Bookings::CancelService.call(booking, actor: booking.passenger)
    end

    assert booking.reload.canceled?
    assert_equal ride.seats, ride.reload.remaining_seats
    assert ride.active?
  end

  test "deleting ride with accepted bookings is prohibited and directs to cancellation" do
    ride = ride_posts(:one)
    booking = bookings(:one)
    booking.update_columns(status: Booking.statuses[:accepted])

    assert_no_difference "RidePost.count" do
      assert_not ride.destroy
    end

    assert_includes ride.errors[:base], "Cannot delete a ride with accepted bookings. Please cancel the trip instead."
  end

  test "deleting ride with trip reviews is restricted" do
    ride = ride_posts(:one)
    booking = bookings(:one)
    booking.update_columns(status: Booking.statuses[:accepted])
    ride.update_columns(departure_time: 2.hours.ago, expected_arrival_at: 1.hour.ago)

    TripReview.create!(
      ride_post: ride,
      reporter: ride.user,
      reported_user: booking.passenger,
      outcome: :completed
    )

    assert_not ride.destroy
    assert_includes ride.errors[:base], "Cannot delete a ride with trip reviews or incident history."
  end
end
