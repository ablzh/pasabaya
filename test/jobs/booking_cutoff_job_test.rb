# frozen_string_literal: true

require "test_helper"

class BookingCutoffJobTest < ActiveJob::TestCase
  setup do
    @driver = users(:one)
    @passenger = users(:two)
    departure = 1.hour.from_now
    @ride = RidePost.create!(
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
    @booking = Booking.create!(ride_post: @ride, passenger: @passenger, status: :pending)
  end

  test "perform expires pending bookings on ride" do
    travel_to @ride.booking_cutoff_at + 1.minute do
      assert_difference("Notification.count", 1) do
        BookingCutoffJob.perform_now(@ride.id)
      end
      assert @booking.reload.expired?
    end
  end

  test "scheduled automatically upon ride creation with future cutoff" do
    post = nil
    assert_enqueued_jobs 1, only: BookingCutoffJob do
      post = RidePost.create!(
        user: @driver,
        origin: locations(:one),
        destination: locations(:two),
        post_type: :offering,
        seats: 3,
        departure_date: 2.days.from_now.to_date,
        departure_choice: :morning,
        status: :active
      )
    end
    assert_equal post.booking_cutoff_at, 2.days.from_now.to_date.in_time_zone("Asia/Manila").end_of_day
  end

  test "recovery sweeps overdue pending bookings" do
    @ride.update_columns(departure_time: 2.hours.ago)
    assert @booking.reload.pending?

    assert_difference("Notification.count", 1) do
      TripAuditRecoveryJob.perform_now
    end

    assert @booking.reload.expired?
  end
end
