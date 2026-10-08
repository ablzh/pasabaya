require "test_helper"

class RidePostTest < ActiveSupport::TestCase
  test "unchanged historical long notes survive cancellation and automatic completion" do
    original = "Historical trip details " * 30
    canceled = ride_posts(:one)
    canceled.update_columns(notes: original)
    RidePosts::CancelService.call(canceled, actor: canceled.user)
    assert canceled.reload.canceled?
    assert_equal original, canceled.notes

    completed = ride_posts(:two)
    completed.update_columns(notes: original, departure_time: 25.hours.ago, expected_arrival_at: nil)
    TripAuditJob.perform_now(completed.id)
    assert completed.reload.completed?
    assert_equal original, completed.notes
  end

  test "new and changed notes allow 300 characters and reject 301" do
    ride = ride_posts(:one).dup
    ride.notes = "a" * 300
    assert ride.save
    ride.notes = "a" * 301
    assert_not ride.save
    assert_includes ride.errors[:notes], "is too long (maximum is 300 characters)"

    fresh = ride_posts(:one).dup
    fresh.notes = "a" * 301
    assert_not fresh.save
    assert_includes fresh.errors[:notes], "is too long (maximum is 300 characters)"
  end

  test "passenger ride posts are invalid while driver offers remain supported" do
    ride = ride_posts(:one).dup
    ride.post_type = :requesting
    assert_not ride.valid?
    assert_includes ride.errors[:post_type], "is not included in the list"
  end

  test "database rejects passenger post intent even when model validation is bypassed" do
    assert_raises(ActiveRecord::StatementInvalid) { ride_posts(:one).update_columns(post_type: 1) }
  end

  test "sold out offers preserve positive capacity" do
    ride = ride_posts(:one)
    ride.remaining_seats = 0
    assert ride.save
    assert ride.full?
    assert_not ride.bookable?
  end

  [ -1, 4 ].each do |inventory|
    test "remaining inventory #{inventory} is rejected by the model and database" do
      ride = ride_posts(:one)
      ride.remaining_seats = inventory
      assert_not ride.valid?
      assert_raises(ActiveRecord::StatementInvalid) { ride.update_columns(remaining_seats: inventory) }
    end
  end

  test "total offered seats must remain positive and present" do
    ride = ride_posts(:one)
    ride.seats = 0
    assert_not ride.valid?
    assert_raises(ActiveRecord::StatementInvalid) { ride.update_columns(seats: 0) }
    assert_raises(ActiveRecord::StatementInvalid) { ride.update_columns(seats: nil) }
  end

  test "publishing requires distinct route future exact departure and available passenger seats" do
    ride = RidePost.new(user: users(:one), origin_id: ride_posts(:one).origin_id,
                        destination_id: ride_posts(:one).origin_id, post_type: :offering,
                        status: :active, seats: 3, remaining_seats: 0, departure_time: 1.hour.ago)
    assert_not ride.valid?
    assert ride.errors[:destination].present?
    assert ride.errors[:departure_time].present?
    assert ride.errors[:remaining_seats].present?
    ride.destination_id = ride_posts(:one).destination_id
    ride.departure_time = 1.day.from_now
    ride.remaining_seats = 3
    assert ride.valid?, ride.errors.full_messages.to_sentence
  end

  test "an incomplete private draft can be saved but cannot publish without route departure and seats" do
    ride = RidePost.new(user: users(:one), post_type: :offering, status: :draft)
    assert ride.save, ride.errors.full_messages.to_sentence
    assert_not ride.bookable?
    ride.status = :active
    assert_not ride.save
    assert ride.errors[:origin].present?
    assert ride.errors[:destination].present?
    assert ride.errors[:departure_time].present?
    assert ride.errors[:seats].present?
  end

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

  test "departed ride with historical participation cannot be deleted or have route/schedule edited after cancellation" do
    ride = ride_posts(:one)
    booking = bookings(:one)
    booking.update_columns(status: Booking.statuses[:accepted], accepted_at: 3.hours.ago)
    ride.update_columns(departure_time: 2.hours.ago, expected_arrival_at: 1.hour.ago)

    # Cancel whole trip post-departure
    RidePosts::CancelService.call(ride, actor: ride.user)
    assert ride.reload.canceled?
    assert booking.reload.canceled?

    # Verify review eligibility is retained for both driver and passenger
    assert ride.reviewable_by?(ride.user)
    assert ride.reviewable_by?(booking.passenger)

    # Route changes must fail
    other_location = locations(:one)
    ride.destination = other_location
    assert_not ride.save
    assert_includes ride.errors[:base], "Cannot modify route, schedule, capacity, or audience for trips with historical participation"

    # Schedule changes to move trip to the future must fail
    ride.reload
    ride.departure_time = 1.day.from_now
    assert_not ride.save
    assert_includes ride.errors[:base], "Cannot modify route, schedule, capacity, or audience for trips with historical participation"

    # Hard deletion must fail and preserve records
    ride.reload
    assert_no_difference "RidePost.count" do
      assert_not ride.destroy
    end
    assert_includes ride.errors[:base], "Cannot delete a departed ride with historical participation. Trip records must be preserved for review eligibility."

    # Booking must still exist and be intact
    assert Booking.exists?(booking.id)
    assert booking.reload.historical_reviewable?
  end

  test "unmatched drafts and pre-departure canceled rides retain normal edit and delete behavior" do
    draft = RidePost.create!(
      user: users(:one),
      origin: locations(:one),
      destination: locations(:two),
      seats: 3,
      post_type: :offering,
      status: :draft
    )
    assert draft.destroy

    # Pre-departure canceled ride without historical participation
    future_ride = RidePost.create!(
      user: users(:one),
      origin: locations(:one),
      destination: locations(:two),
      seats: 3,
      departure_time: 2.days.from_now,
      expected_arrival_at: 2.days.from_now + 3.hours,
      remaining_seats: 3,
      post_type: :offering,
      status: :active
    )
    RidePosts::CancelService.call(future_ride, actor: users(:one))
    assert future_ride.reload.canceled?
    assert future_ride.destroy
  end

  test "filter_by_departure_date returns rides departing on target day" do
    target_date = 2.days.from_now.to_date
    ride_matching = ride_posts(:one)
    ride_matching.update_columns(departure_date: target_date, departure_time: target_date.to_time + 10.hours)

    ride_other = ride_posts(:two)
    ride_other.update_columns(departure_date: target_date + 3.days, departure_time: (target_date + 3.days).to_time)

    results = RidePost.filter_by_departure_date(target_date.to_s)
    assert_includes results, ride_matching
    assert_not_includes results, ride_other
  end

  test "approximate departure sets booking cutoff to end of day in Asia/Manila and keeps departure_time nil" do
    ride = RidePost.create!(
      user: users(:one),
      origin: locations(:one),
      destination: locations(:two),
      seats: 3,
      post_type: :offering,
      departure_date: Date.current + 2.days,
      departure_choice: :morning,
      status: :active
    )

    assert_nil ride.departure_time
    assert_equal (Date.current + 2.days).in_time_zone("Asia/Manila").end_of_day, ride.booking_cutoff_at
    assert_equal ride.booking_cutoff_at + 24.hours, ride.automatic_completion_at
    assert ride.bookable?
  end

  test "approximate ride requests and acceptance remain open on departure date even after named period passed" do
    target_date = Date.current
    ride = RidePost.create!(
      user: users(:one),
      origin: locations(:one),
      destination: locations(:two),
      seats: 3,
      post_type: :offering,
      departure_date: target_date,
      departure_choice: :morning,
      status: :active
    )

    # 2:00 PM is after morning (06:00-12:00), but on the departure date
    travel_to target_date.in_time_zone("Asia/Manila").change(hour: 14, min: 0) do
      assert ride.bookable?
      booking = Booking.create!(ride_post: ride, passenger: users(:two), status: :pending)
      assert booking.persisted?
      assert_nothing_raised do
        Bookings::AcceptService.call(booking, actor: users(:one))
      end
      assert booking.reload.accepted?
    end
  end

  test "exact time booking closes at specified departure time" do
    departure = 2.hours.from_now
    ride = RidePost.create!(
      user: users(:one),
      origin: locations(:one),
      destination: locations(:two),
      seats: 3,
      post_type: :offering,
      departure_date: departure.to_date,
      departure_choice: :exact_time,
      departure_time: departure,
      status: :active
    )

    assert_equal departure, ride.booking_cutoff_at
    assert ride.bookable?

    travel_to departure + 1.minute do
      assert_not ride.bookable?
    end
  end

  test "locked schedule attributes cannot be edited when accepted bookings exist" do
    ride = RidePost.create!(
      user: users(:one),
      origin: locations(:one),
      destination: locations(:two),
      seats: 3,
      post_type: :offering,
      departure_date: Date.current + 2.days,
      departure_choice: :afternoon,
      status: :active
    )
    Booking.create!(ride_post: ride, passenger: users(:two), status: :accepted)

    ride.departure_choice = :evening
    assert_not ride.valid?
    assert_includes ride.errors[:base], "Cannot modify route, schedule, capacity, or audience while accepted bookings exist"

    ride.reload
    ride.departure_date = Date.current + 3.days
    assert_not ride.valid?
    assert_includes ride.errors[:base], "Cannot modify route, schedule, capacity, or audience while accepted bookings exist"
  end

  test "review eligibility for approximate vs exact departure" do
    target_date = Date.tomorrow
    approx_ride = RidePost.create!(
      user: users(:one),
      origin: locations(:one),
      destination: locations(:two),
      seats: 3,
      post_type: :offering,
      departure_date: target_date,
      departure_choice: :morning,
      status: :active
    )

    exact_time = target_date.in_time_zone("Asia/Manila").change(hour: 10, min: 0)
    exact_ride = RidePost.create!(
      user: users(:one),
      origin: locations(:one),
      destination: locations(:two),
      seats: 3,
      post_type: :offering,
      departure_date: target_date,
      departure_choice: :exact_time,
      departure_time: exact_time,
      status: :active
    )

    # During the departure date at 14:00:
    travel_to target_date.in_time_zone("Asia/Manila").change(hour: 14, min: 0) do
      # Exact ride departed at 10:00 -> reviewable!
      assert exact_ride.reviewable_trip?
      # Approximate ride is still within the departure date -> NOT reviewable until date ends!
      assert_not approx_ride.reviewable_trip?
    end

    # The next day at 00:01:
    travel_to (target_date + 1.day).in_time_zone("Asia/Manila").change(hour: 0, min: 1) do
      assert approx_ride.reviewable_trip?
    end
  end
end
