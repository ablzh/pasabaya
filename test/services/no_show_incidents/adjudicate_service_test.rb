# frozen_string_literal: true

require "test_helper"

class NoShowIncidents::AdjudicateServiceTest < ActiveSupport::TestCase
  setup do
    @origin = Location.create!(name: "Adj Origin", location_type: :city)
    @destination = Location.create!(name: "Adj Dest", location_type: :city)
    @driver = users(:one)
    @user = users(:two) # passenger
    @moderator = User.create!(email_address: "moderator@example.test", password: "password",
      first_name: "Independent", last_name: "Moderator", admin: true)

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

    adjudicate(
      incident,
      status: :upheld,
      reviewer: @moderator,
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
    adjudicate(inc1, status: :upheld)
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
    adjudicate(inc2, status: :upheld)
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
    adjudicate(inc3, status: :upheld)
    assert_equal 3, @user.recent_upheld_incidents_count
    assert @user.reload.booking_frozen?

    # Dismissal on appeal reduces strikes and unfreezes
    adjudicate(inc3.reload, status: :dismissed, reason: "Evidence of emergency provided")
    assert_equal 2, @user.recent_upheld_incidents_count
    assert_not @user.reload.booking_frozen?
  end

  test "repeated adjudication does not extend freeze or duplicate notifications" do
    inc = NoShowIncident.create!(ride_post: @ride_post, user: @user, status: :pending, occurred_at: 1.day.ago)
    @user.update_columns(booking_freeze_until: 7.days.from_now)
    original_freeze = @user.reload.booking_freeze_until

    assert_difference -> { Notification.where(event_name: "incident.resolved").count } => 1 do
      adjudicate(inc, status: :upheld)
    end

    assert_equal original_freeze.to_i, @user.reload.booking_freeze_until.to_i

    # Reprocessing one hour later
    travel 1.hour do
      assert_no_difference -> { Notification.where(event_name: "incident.resolved").count } do
        adjudicate(inc, status: :upheld)
      end

      assert_equal original_freeze.to_i, @user.reload.booking_freeze_until.to_i
    end
  end

  test "adjudicates retained incidents without notifying or modifying deleted accounts" do
    incident = NoShowIncident.create!(ride_post: @ride_post, user: @user, status: :pending, occurred_at: Time.current)
    assert Users::AnonymizeService.call(@user)

    assert_no_difference("Notification.count") do
      adjudicate(incident, status: :upheld, reviewer: @moderator)
    end

    assert incident.reload.upheld?
    assert @user.reload.deleted?
    assert_nil @user.booking_freeze_until
  end
  test "each reversal records a decision and notifies without overwriting evidence" do
    incident = NoShowIncident.create!(ride_post: @ride_post, user: @user, occurred_at: 1.day.ago)
    reasons = [ "Initial evidence", "Corrected evidence", "New evidence" ]
    [ :upheld, :dismissed, :upheld ].each_with_index do |status, index|
      assert_difference [ "NoShowIncidentDecision.count", "Notification.count" ], 1 do
        adjudicate(incident.reload, status: status, reason: reasons[index])
      end
    end
    assert_equal reasons, incident.decisions.order(:id).pluck(:reason)
    assert_equal [ "pending", "upheld", "dismissed" ], incident.decisions.order(:id).map(&:previous_status)
    assert_equal 3, Notification.where(event_name: "incident.resolved").distinct.count(:delivery_key)
  end

  test "correcting a legacy decision preserves its known author reason and time" do
    original_reason = "x" * 2001 # Older console decisions did not have the new limit.
    original_time = 2.days.ago.change(usec: 0)
    incident = NoShowIncident.create!(ride_post: @ride_post, user: @user,
      occurred_at: 3.days.ago, status: :upheld, reviewer: @driver,
      decision_reason: original_reason, resolved_at: original_time)

    assert_difference "NoShowIncidentDecision.count", 2 do
      assert_difference "Notification.count", 1 do
        adjudicate(incident, status: :dismissed, reason: "Corrected after reviewing the report")
      end
    end

    legacy = incident.decisions.find_by!(legacy: true)
    assert legacy.upheld?
    assert_nil legacy.previous_status
    assert_equal @driver.id, legacy.reviewer_id
    assert_equal original_reason, legacy.reason
    assert_equal original_time, legacy.created_at
    assert_nil legacy.booking_freeze_until
    assert_not Notification.exists?(notifiable: legacy)
    decision = incident.decisions.find_by!(legacy: false)
    assert decision.dismissed?
    assert_equal "upheld", decision.previous_status
  end

  test "a legacy snapshot preserves known metadata without restoring deleted personal text" do
    original_time = 2.days.ago.change(usec: 0)
    incident = NoShowIncident.create!(ride_post: @ride_post, user: @user,
      occurred_at: 3.days.ago, status: :upheld, reviewer: @driver,
      decision_reason: "Their private phone is 0917-123-4567", resolved_at: original_time)
    assert Users::AnonymizeService.call(@user)

    assert_no_difference "Notification.count" do
      adjudicate(incident, status: :dismissed, reason: "The private phone was 0917-123-4567")
    end

    legacy = incident.decisions.find_by!(legacy: true)
    assert_nil legacy.reason
    assert_equal @driver.id, legacy.reviewer_id
    assert_equal original_time, legacy.created_at
    assert_no_match(/0917/, incident.reload.decision_reason)
  end

  test "a stale conflicting decision cannot overwrite another administrator" do
    incident = NoShowIncident.create!(ride_post: @ride_post, user: @user, occurred_at: 1.day.ago)
    stale = NoShowIncident.find(incident.id)
    adjudicate(incident, status: :upheld)

    assert_no_difference [ "NoShowIncidentDecision.count", "Notification.count" ] do
      assert_raises(NoShowIncidents::AdjudicateService::Conflict) do
        adjudicate(stale, status: :dismissed)
      end
    end
    assert incident.reload.upheld?
  end

  test "only an exact replay of the previous submission is idempotent" do
    incident = NoShowIncident.create!(ride_post: @ride_post, user: @user, occurred_at: 1.day.ago)
    adjudicate(incident, status: :upheld, reason: "Original decision")
    assert_no_difference [ "NoShowIncidentDecision.count", "Notification.count" ] do
      adjudicate(incident, status: :upheld, reason: "Original decision")
      assert_raises(NoShowIncidents::AdjudicateService::Conflict) do
        adjudicate(incident, status: :upheld, reason: "Different evidence")
      end
    end
  end

  test "revoked administrator cannot write through a previously loaded user" do
    incident = NoShowIncident.create!(ride_post: @ride_post, user: @user, occurred_at: 1.day.ago)
    User.where(id: @moderator.id).update_all(admin: false)
    assert @moderator.admin?
    assert_no_difference [ "NoShowIncidentDecision.count", "Notification.count" ] do
      assert_raises(NoShowIncidents::AdjudicateService::Error) { adjudicate(incident, status: :upheld) }
    end
    assert incident.reload.pending?
  end

  test "missing banned deleted and involved moderators cannot decide" do
    incident = NoShowIncident.create!(ride_post: @ride_post, user: @user, occurred_at: 1.day.ago)
    User.where(id: @driver.id).update_all(admin: true)
    [ nil, @driver.reload, @user ].each do |reviewer|
      assert_raises(NoShowIncidents::AdjudicateService::Error) do
        adjudicate(incident, status: :upheld, reviewer: reviewer)
      end
    end
    @moderator.update!(banned_at: Time.current)
    assert_raises(NoShowIncidents::AdjudicateService::Error) { adjudicate(incident, status: :upheld) }
    @moderator.update!(banned_at: nil)
    assert Users::AnonymizeService.call(@moderator)
    assert_raises(NoShowIncidents::AdjudicateService::Error) { adjudicate(incident, status: :upheld) }
    assert incident.reload.pending?
    assert_empty incident.decisions
  end

  test "a former booking participant cannot moderate their own trip" do
    Booking.create!(ride_post: @ride_post, passenger: @moderator, status: :declined)
    incident = NoShowIncident.create!(ride_post: @ride_post, user: @user, occurred_at: 1.day.ago)
    assert_raises(NoShowIncidents::AdjudicateService::Error) { adjudicate(incident, status: :upheld) }
    assert incident.reload.pending?
  end

  test "only final statuses and meaningful reasons are accepted" do
    incident = NoShowIncident.create!(ride_post: @ride_post, user: @user, occurred_at: 1.day.ago)
    [ { status: :pending }, { status: :appealed }, { status: :invalid },
      { reason: " " }, { reason: "x" * 2001 }, { expected_version: nil } ].each do |invalid|
      assert_raises(NoShowIncidents::AdjudicateService::Error) do
        adjudicate(incident, **{ status: :upheld }.merge(invalid))
      end
    end
    assert incident.reload.pending?
    assert_empty incident.decisions
  end

  test "notification failure rolls back decision strikes and freeze" do
    # Fixture construction invokes independent model writes, not a listing query.
    Prosopite.pause do
      2.times do |index|
        ride = @ride_post.dup
        ride.user = @driver
        ride.origin = @origin
        ride.destination = @destination
        ride.save!
        NoShowIncident.create!(ride_post: ride, user: @user, occurred_at: index.days.ago, status: :upheld)
      end
    end
    incident = NoShowIncident.create!(ride_post: @ride_post, user: @user, occurred_at: 1.day.ago)
    with_stubbed_method(Notification, :create!, ->(*) { raise "notification failure" }) do
      assert_no_difference "NoShowIncidentDecision.count" do
        assert_raises(RuntimeError) { adjudicate(incident, status: :upheld) }
      end
    end
    assert incident.reload.pending?
    assert_equal 2, @user.recent_upheld_incidents_count
    assert_nil @user.reload.booking_freeze_until
  end

  test "retained case decisions cannot restore deleted personal details" do
    incident = NoShowIncident.create!(ride_post: @ride_post, user: @user, occurred_at: 1.day.ago)
    assert Users::AnonymizeService.call(@user)
    adjudicate(incident, status: :upheld, reason: "Their private phone is 0917-123-4567")
    assert_no_match(/0917/, incident.reload.decision_reason)
    assert_no_match(/0917/, incident.decisions.first.reason)
  end

  private

  def adjudicate(incident, **attributes)
    # These calls represent separate requests; check each request for N+1s.
    Prosopite.finish
    Prosopite.scan
    NoShowIncidents::AdjudicateService.call(incident,
      **{ reviewer: @moderator, reason: "Evidence reviewed" }.merge(attributes))
  ensure
    Prosopite.finish
    Prosopite.scan
  end
end
