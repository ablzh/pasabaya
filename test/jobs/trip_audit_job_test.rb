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

  test "recovery handles overdue rides without arrival but excludes drafts and canceled rides" do
    @ride_post.update_columns(departure_time: 25.hours.ago, expected_arrival_at: nil)
    draft = ride_posts(:one)
    draft.update_columns(status: RidePost.statuses[:draft], departure_time: 25.hours.ago, expected_arrival_at: nil)
    canceled = ride_posts(:two)
    canceled.update_columns(status: RidePost.statuses[:canceled], departure_time: 25.hours.ago, expected_arrival_at: nil)
    clear_enqueued_jobs
    assert_enqueued_with(job: TripAuditJob, args: [ @ride_post.id ]) { TripAuditRecoveryJob.perform_now }
    perform_enqueued_jobs(only: TripAuditJob)
    assert @ride_post.reload.completed?
    assert draft.reload.draft?
    assert canceled.reload.canceled?
    assert_no_enqueued_jobs(only: TripAuditJob) do
      # Separate job executions each have their own query scan in production.
      Prosopite.finish
      Prosopite.scan
      TripAuditRecoveryJob.perform_now
    end
  end

  test "completion never precedes booking cutoff even with inconsistent legacy arrival" do
    @ride_post.update_columns(departure_time: 1.hour.from_now, expected_arrival_at: 4.hours.ago)
    TripAuditJob.perform_now(@ride_post.id)
    assert @ride_post.reload.published?
    assert_equal @ride_post.departure_time, @ride_post.automatic_completion_at
  end

  test "without arrival completion waits until departure plus 24 hours and schedules the same deadline" do
    ride = ride_posts(:one)
    ride.expected_arrival_at = nil
    assert_enqueued_with(job: TripAuditJob, at: ride.departure_time + 24.hours) { ride.save! }
    ride.update_columns(departure_time: 23.hours.ago.change(usec: 0))
    TripAuditJob.perform_now(ride.id)
    assert ride.reload.active?
    travel_to ride.departure_time + 24.hours do
      TripAuditJob.perform_now(ride.id)
      assert ride.reload.completed?
    end
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
    assert_not Notification.exists?(notifiable: @ride_post, event_name: "review.requested")
  end

  test "completion does not prompt banned or deleted participants to review" do
    @ride_post.update_columns(departure_time: 5.hours.ago, expected_arrival_at: 3.hours.ago)
    @driver.update_columns(banned_at: Time.current)
    @passenger.update_columns(deleted_at: Time.current)

    assert_no_difference -> { Notification.where(event_name: "review.requested").count } do
      TripAuditJob.perform_now(@ride_post.id)
    end
    assert @ride_post.reload.completed?
  end
end
