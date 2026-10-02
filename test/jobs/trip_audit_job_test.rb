# frozen_string_literal: true

require "test_helper"

class TripAuditJobTest < ActiveJob::TestCase
  setup do
    @origin = Location.create!(name: "Audit Origin", location_type: :city)
    @destination = Location.create!(name: "Audit Dest", location_type: :city)
    @driver = users(:one)
    @passenger = users(:two)

    @ride_post = RidePost.create!(
      user: @driver,
      origin: @origin,
      destination: @destination,
      post_type: :offering,
      seats: 3,
      remaining_seats: 2,
      status: :active,
      departure_time: 1.day.from_now,
      expected_arrival_at: 1.day.from_now + 2.hours
    )
    @booking = Booking.create!(ride_post: @ride_post, passenger: @passenger, status: :accepted)
  end

  test "skips execution if expected arrival time has not passed plus 2 hours" do
    assert_no_difference -> { Notification.where(event_name: "review.requested").count } do
      TripAuditJob.perform_now(@ride_post.id)
    end
  end

  test "perform generates review.requested notifications for trip participants once arrived" do
    @ride_post.update_columns(departure_time: 5.hours.ago, expected_arrival_at: 3.hours.ago)

    assert_difference -> { Notification.where(event_name: "review.requested").count }, 2 do
      TripAuditJob.perform_now(@ride_post.id)
    end

    driver_notif = Notification.find_by(recipient: @driver, event_name: "review.requested")
    passenger_notif = Notification.find_by(recipient: @passenger, event_name: "review.requested")

    assert_not_nil driver_notif
    assert_not_nil passenger_notif
    assert @ride_post.reload.completed?

    # Idempotent: repeated run should not create duplicate notifications
    assert_no_difference -> { Notification.where(event_name: "review.requested").count } do
      TripAuditJob.perform_now(@ride_post.id)
    end
  end

  test "expires unanswered requests when a trip completes" do
    @booking.update_columns(status: Booking.statuses[:pending], accepted_at: nil)
    @ride_post.update_columns(departure_time: 5.hours.ago, expected_arrival_at: 3.hours.ago)
    TripAuditJob.perform_now(@ride_post.id)
    assert @ride_post.reload.completed?
    assert @booking.reload.expired?
    assert_not Notification.exists?(recipient: @passenger, notifiable: @ride_post, event_name: "review.requested")
  end
end
