require "test_helper"
require Rails.root.join("db/migrate/20261004000200_correct_exact_departure_dates")

class ExactDepartureDateMigrationTest < ActiveSupport::TestCase
  test "legacy exact departures regain their Philippine date without moving the accepted trip" do
    ride = ride_posts(:one)
    departure = Time.zone.local(2026, 10, 5, 1)
    ride.update_columns(departure_time: departure, departure_date: Date.new(2026, 10, 4))
    bookings(:one).update_columns(status: Booking.statuses[:accepted], accepted_at: Time.zone.local(2026, 10, 3, 12))

    CorrectExactDepartureDates.new.up

    assert_equal Date.new(2026, 10, 5), ride.reload.departure_date
    assert_equal departure, ride.departure_time
    assert_equal departure, ride.booking_cutoff_at
    assert bookings(:one).reload.accepted?
    assert_includes RidePost.filter_by_departure_date("2026-10-05"), ride
  end
end
