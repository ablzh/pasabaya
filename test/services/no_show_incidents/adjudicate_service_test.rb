# frozen_string_literal: true

require "test_helper"

class NoShowIncidents::AdjudicateServiceTest < ActiveSupport::TestCase
  setup do
    @origin = Location.create!(name: "Adj Origin", location_type: :city)
    @destination = Location.create!(name: "Adj Dest", location_type: :city)
    @driver = users(:one)
    @user = users(:two) # passenger

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

  test "upholding incident creates notification and tracks strikes" do
    incident = NoShowIncident.create!(
      ride_post: @ride_post,
      user: @user,
      status: :pending,
      occurred_at: Time.current
    )

    NoShowIncidents::AdjudicateService.call(
      incident,
      status: :upheld,
      reviewer: @driver,
      reason: "Passenger verified no-show without notice"
    )

    assert incident.reload.upheld?
    assert_equal 1, @user.recent_upheld_incidents_count
    assert_not @user.reliability_warning?
    assert_not @user.booking_frozen?

    notification = Notification.find_by(recipient: @user, event_name: "incident.resolved")
    assert_not_nil notification
  end

  test "progressive accountability: 2 strikes trigger warning, 3 strikes trigger booking freeze" do
    # 1st strike
    inc1 = NoShowIncident.create!(ride_post: @ride_post, user: @user, status: :pending, occurred_at: 10.days.ago)
    NoShowIncidents::AdjudicateService.call(inc1, status: :upheld)
    assert_equal 1, @user.recent_upheld_incidents_count
    assert_not @user.reliability_warning?
    assert_not @user.booking_frozen?

    # 2nd strike
    ride2 = RidePost.create!(
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
    inc2 = NoShowIncident.create!(ride_post: ride2, user: @user, status: :pending, occurred_at: 5.days.ago)
    NoShowIncidents::AdjudicateService.call(inc2, status: :upheld)
    assert_equal 2, @user.recent_upheld_incidents_count
    assert @user.reliability_warning?
    assert_not @user.booking_frozen?

    # 3rd strike
    ride3 = RidePost.create!(
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
    inc3 = NoShowIncident.create!(ride_post: ride3, user: @user, status: :pending, occurred_at: 1.day.ago)
    NoShowIncidents::AdjudicateService.call(inc3, status: :upheld)
    assert_equal 3, @user.recent_upheld_incidents_count
    assert @user.reload.booking_frozen?

    # Dismissal on appeal reduces strikes and unfreezes
    NoShowIncidents::AdjudicateService.call(inc3, status: :dismissed, reason: "Evidence of emergency provided")
    assert_equal 2, @user.recent_upheld_incidents_count
    assert_not @user.reload.booking_frozen?
  end

  test "repeated adjudication does not extend freeze or duplicate notifications" do
    inc = NoShowIncident.create!(ride_post: @ride_post, user: @user, status: :pending, occurred_at: 1.day.ago)
    @user.update_columns(booking_freeze_until: 7.days.from_now)
    original_freeze = @user.reload.booking_freeze_until

    assert_difference -> { Notification.where(event_name: "incident.resolved").count } => 1 do
      NoShowIncidents::AdjudicateService.call(inc, status: :upheld)
    end

    assert_equal original_freeze.to_i, @user.reload.booking_freeze_until.to_i

    # Reprocessing one hour later
    travel 1.hour do
      assert_no_difference -> { Notification.where(event_name: "incident.resolved").count } do
        NoShowIncidents::AdjudicateService.call(inc, status: :upheld)
      end

      assert_equal original_freeze.to_i, @user.reload.booking_freeze_until.to_i
    end
  end
end
