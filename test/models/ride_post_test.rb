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
end
