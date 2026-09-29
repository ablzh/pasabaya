# frozen_string_literal: true

require "test_helper"

class NoShowIncidentTest < ActiveSupport::TestCase
  setup do
    @origin = Location.create!(name: "Incident Origin", location_type: :city)
    @destination = Location.create!(name: "Incident Dest", location_type: :city)
    @user = users(:two)
    @driver = users(:one)

    @ride_post = RidePost.create!(
      user: @driver,
      origin: @origin,
      destination: @destination,
      post_type: :offering,
      seats: 3,
      remaining_seats: 3,
      status: :active,
      departure_time: 1.day.from_now,
      expected_arrival_at: 1.day.from_now + 2.hours
    )
  end

  test "valid incident creation" do
    incident = NoShowIncident.new(
      ride_post: @ride_post,
      user: @user,
      status: :pending,
      occurred_at: Time.current,
      decision_reason: "Passenger was not at pickup point"
    )
    assert incident.valid?
  end

  test "enforces single incident per user per trip" do
    NoShowIncident.create!(
      ride_post: @ride_post,
      user: @user,
      status: :pending,
      occurred_at: Time.current
    )

    duplicate = NoShowIncident.new(
      ride_post: @ride_post,
      user: @user,
      status: :upheld,
      occurred_at: Time.current
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:ride_post_id], "already has an incident recorded for this trip"
  end

  test "recent strikes scope respects 60-day window and upheld status" do
    # Recent upheld incident (within 60 days)
    NoShowIncident.create!(
      ride_post: @ride_post,
      user: @user,
      status: :upheld,
      occurred_at: 10.days.ago
    )

    # Older upheld incident (75 days ago)
    old_ride = RidePost.create!(
      user: @driver,
      origin: @origin,
      destination: @destination,
      post_type: :offering,
      seats: 3,
      remaining_seats: 3,
      status: :active,
      departure_time: 2.days.from_now,
      expected_arrival_at: 2.days.from_now + 2.hours
    )
    NoShowIncident.create!(
      ride_post: old_ride,
      user: @user,
      status: :upheld,
      occurred_at: 75.days.ago
    )

    # Pending incident (not counted as strike)
    pending_ride = RidePost.create!(
      user: @driver,
      origin: @origin,
      destination: @destination,
      post_type: :offering,
      seats: 3,
      remaining_seats: 3,
      status: :active,
      departure_time: 3.days.from_now,
      expected_arrival_at: 3.days.from_now + 2.hours
    )
    NoShowIncident.create!(
      ride_post: pending_ride,
      user: @user,
      status: :pending,
      occurred_at: 2.days.ago
    )

    assert_equal 1, @user.recent_upheld_incidents_count
    assert_not @user.reliability_warning?
  end
end
