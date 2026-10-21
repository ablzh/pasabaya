require "test_helper"

class RideSchedulesTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.local(2026, 10, 8, 10)
    @driver = users(:one)
    @passenger = users(:two)
    @schedule = @driver.ride_schedules.build
    origin = locations(:one)
    destination = locations(:two)
    RideSchedules::ConfigureService.call(schedule: @schedule, actor: @driver, attributes: {
      origin: origin, destination: destination, weekday_ids: [ 1 ],
      departure_choice: :exact_time, departure_clock: "08:00", seats: 3, status: :active
    })
    @first = @schedule.ride_posts.find_by!(departure_date: Date.new(2026, 10, 12))
    @next_week = @schedule.ride_posts.find_by!(departure_date: Date.new(2026, 10, 19))
  end

  teardown { travel_back }

  test "each Monday owns its seats and historical participation" do
    booking = Bookings::CreateService.call(ride_post: @first, passenger: @passenger)
    Bookings::AcceptService.call(booking, actor: @driver)
    assert_equal 2, @first.reload.remaining_seats
    assert_equal 3, @next_week.reload.remaining_seats
    assert @next_week.bookable?

    travel_to Time.zone.local(2026, 10, 13, 10)
    TripAuditJob.perform_now(@first.id)
    assert @first.reload.completed?
    assert @first.reviewable_by?(@passenger)
    assert_not @next_week.reviewable_by?(@passenger)
    assert_equal 3, @next_week.reload.remaining_seats
  end

  test "refresh is idempotent and retains cancelled and manually closed departures" do
    RidePosts::CancelService.call(@first, actor: @driver)
    RidePosts::CloseRequestsService.call(@next_week, actor: @driver)
    assert_no_difference "RidePost.count" do
      RideSchedules::MaterializeService.call(@schedule)
      RideSchedules::MaterializeService.call(@schedule)
    end
    assert @first.reload.canceled?
    assert @next_week.reload.requests_closed_at.present?
    assert_not @first.destroy
  end

  test "full schedule descriptions survive updates and new departures" do
    notes = "Detailed pickup and luggage information. " * 30
    RideSchedules::ConfigureService.call(schedule: @schedule, actor: @driver, attributes: { notes: notes })
    assert_equal notes, @schedule.reload.notes
    assert_equal [ notes ], @schedule.ride_posts.pluck(:notes).uniq

    travel_to Time.zone.local(2026, 10, 20, 10)
    RideSchedules::MaterializeService.call(@schedule)
    assert_equal notes, @schedule.ride_posts.find_by!(departure_date: Date.new(2026, 10, 26)).notes
  end

  test "pause expires pending requests but preserves accepted seats and manual closures on resume" do
    accepted = Bookings::CreateService.call(ride_post: @first, passenger: @passenger)
    Bookings::AcceptService.call(accepted, actor: @driver)
    pending = Bookings::CreateService.call(ride_post: @next_week, passenger: @passenger)
    RideSchedules::TransitionService.call(schedule: @schedule, actor: @driver, action: :pause)
    assert accepted.reload.accepted?
    assert pending.reload.expired?
    assert Notification.exists?(event_name: "booking.expired", notifiable: pending)
    assert_equal 2, @first.reload.remaining_seats
    assert_not @first.bookable?
    assert_raises(ActiveRecord::RecordInvalid) { Bookings::CreateService.call(ride_post: @first, passenger: @passenger) }
    assert_raises(Bookings::AcceptService::InvalidStateError) { Bookings::AcceptService.call(pending, actor: @driver) }
    RidePosts::CloseRequestsService.call(@next_week, actor: @driver)
    closed_at = @next_week.reload.requests_closed_at
    RideSchedules::TransitionService.call(schedule: @schedule, actor: @driver, action: :resume)
    assert_equal closed_at, @next_week.reload.requests_closed_at
    assert pending.reload.expired?
    assert @first.reload.bookable?
  end

  test "schedule changes preserve requested departures and update only untouched dates" do
    booking = Bookings::CreateService.call(ride_post: @first, passenger: @passenger)
    assert_not @first.update(seats: 4)
    @first.reload
    RideSchedules::ConfigureService.call(schedule: @schedule, actor: @driver, attributes: { departure_clock: "09:00", seats: 4, weekday_ids: [ 1, 2 ] })
    assert booking.reload.pending?
    assert_equal 8, @first.reload.departure_time.hour
    assert_equal 3, @first.seats
    assert_equal 9, @next_week.reload.departure_time.hour
    assert_equal 4, @next_week.remaining_seats
    assert @schedule.ride_posts.exists?(departure_date: Date.new(2026, 10, 13))
    Bookings::AcceptService.call(booking, actor: @driver)
    RideSchedules::ConfigureService.call(schedule: @schedule, actor: @driver, attributes: { weekday_ids: [ 2 ] })
    assert @first.reload.active?
    assert @next_week.reload.canceled?
  end

  test "ending a series cancels its future bookings once and keeps the records" do
    booking = Bookings::CreateService.call(ride_post: @first, passenger: @passenger)
    Bookings::AcceptService.call(booking, actor: @driver)
    RideSchedules::TransitionService.call(schedule: @schedule, actor: @driver, action: :cancel_future)
    RideSchedules::TransitionService.call(schedule: @schedule, actor: @driver, action: :cancel_future)
    assert @schedule.reload.archived?
    assert booking.reload.canceled?
    assert @schedule.ride_posts.all?(&:canceled?)
    assert_equal 1, Notification.where(event_name: "ride.canceled", recipient: @passenger).count
    assert_raises(RideSchedules::TransitionService::Error) { RideSchedules::TransitionService.call(schedule: @schedule, actor: @driver, action: :resume) }
  end

  test "refresh extends the window without backfilling missed departures" do
    travel_to Time.zone.local(2026, 10, 20, 10)
    RideScheduleRefreshJob.perform_now
    assert_equal [ Date.new(2026, 10, 26), Date.new(2026, 11, 2) ], @schedule.ride_posts.where("departure_date >= ?", Date.current).order(:departure_date).pluck(:departure_date)
    assert_equal 4, @schedule.ride_posts.count
  end

  test "a direct request or acceptance cannot bypass the booking window or paused state" do
    outside = @schedule.ride_posts.create!(@schedule.ride_attributes(Date.new(2026, 10, 26)).merge(schedule_date: Date.new(2026, 10, 26)))
    assert_raises(ActiveRecord::RecordInvalid) { Bookings::CreateService.call(ride_post: outside, passenger: @passenger) }
    pending = Bookings::CreateService.call(ride_post: @first, passenger: @passenger)
    @schedule.update!(status: :paused)
    assert_raises(Bookings::AcceptService::InvalidStateError) { Bookings::AcceptService.call(pending, actor: @driver) }
    assert pending.reload.pending?
  end

  test "a regular departure cannot be moved to another date" do
    assert_not @first.update(departure_date: @first.departure_date + 1.day)
    assert @first.errors[:departure_date].present?
  end

  test "an ineligible driver cannot regenerate departures" do
    @driver.update!(banned_at: Time.current)
    assert_raises(ActiveRecord::RecordInvalid) { Bookings::CreateService.call(ride_post: @first, passenger: @passenger) }
    RideSchedules::MaterializeService.call(@schedule)
    assert @schedule.reload.paused?
    travel_to Time.zone.local(2026, 10, 20, 10)
    assert_no_difference "RidePost.count" do
      RideScheduleRefreshJob.perform_now
    end
  end

  test "losing verified hub membership pauses generation and cancels its departures" do
    hub = communities(:one)
    membership = community_memberships(:one)
    RideSchedules::ConfigureService.call(schedule: @schedule, actor: @driver, attributes: { visibility: :hub_only, community: hub })
    membership.revoke!
    assert @schedule.reload.paused?
    assert @schedule.ride_posts.all?(&:canceled?)
    assert_raises(ActiveRecord::RecordInvalid) { RideSchedules::TransitionService.call(schedule: @schedule, actor: @driver, action: :resume) }
  end

  test "account deletion scrubs schedule notes and stops generation" do
    RideSchedules::ConfigureService.call(schedule: @schedule, actor: @driver, attributes: { notes: "Personal recurring details" })
    assert Users::AnonymizeService.call(@driver)
    assert @schedule.reload.paused?
    assert_nil @schedule.notes
    assert @schedule.ride_posts.all?(&:canceled?)
    assert_not @first.reload.bookable?
  end

  test "schedule expiry stops new dates without erasing existing commitments" do
    RideSchedules::ConfigureService.call(schedule: @schedule, actor: @driver, attributes: { end_date: Date.new(2026, 10, 12) })
    assert @next_week.reload.canceled?
    assert @first.reload.bookable?
    assert_equal [ Date.new(2026, 10, 12) ], @schedule.generation_dates
  end

  test "changing today's departure to an elapsed time skips it without rejecting the weekly schedule" do
    RideSchedules::ConfigureService.call(schedule: @schedule, actor: @driver, attributes: { weekday_ids: [ 4 ], departure_clock: "12:00" })
    today = @schedule.ride_posts.find_by!(departure_date: Date.current)
    RideSchedules::ConfigureService.call(schedule: @schedule, actor: @driver, attributes: { departure_clock: "08:00" })
    assert today.reload.canceled?
    next_thursday = @schedule.ride_posts.find_by!(departure_date: Date.current + 7)
    assert_equal 8, next_thursday.departure_time.hour
    assert next_thursday.bookable?
  end

  test "refresh never moves an elapsed departure back into the future" do
    travel_to Time.zone.local(2026, 10, 12, 10)
    RideSchedules::ConfigureService.call(schedule: @schedule, actor: @driver, attributes: { departure_clock: "16:00" })
    assert_equal 8, @first.reload.departure_time.hour
    assert_not @first.bookable?
    assert_equal 16, @next_week.reload.departure_time.hour
  end
end
