require "application_system_test_case"

class RegularRidesTest < ApplicationSystemTestCase
  setup { travel_to Time.zone.local(2026, 10, 8, 10) }
  teardown { travel_back }

  test "driver publishes a weekly schedule and a passenger books only one date" do
    sign_in(users(:one))
    visit new_ride_post_path
    find("#ride_post_origin_id-ts-control").click
    find(".ts-dropdown .option", text: "Manila").click
    find("#ride_post_destination_id-ts-control").click
    find(".ts-dropdown .option", text: "Makati").click
    fill_in "Departure Date", with: Date.tomorrow
    choose "Exact Time"
    fill_in "Departure Time", with: "08:00"
    fill_in "Available passenger seats", with: 3
    fill_in "Details & Preferences", with: "Meet near the station"
    choose "Regular"
    assert_current_path new_ride_post_path
    assert_no_field "Departure Date"
    assert_field "Departure Time", with: "08:00"
    assert_field "Details & Preferences", with: "Meet near the station"
    check "Monday"
    choose "One-time"
    assert_field "Departure Date", with: Date.tomorrow.to_s
    assert_field "Available passenger seats", with: "3"
    choose "Regular"
    assert_checked_field "Monday"
    click_button "Publish regular ride"
    assert_text "Regular schedule saved"
    schedule = users(:one).ride_schedules.last
    assert_equal "Meet near the station", schedule.notes
    assert_equal locations(:one).id, schedule.origin_id
    assert_equal locations(:two).id, schedule.destination_id
    departures = schedule.ride_posts.order(:departure_date).to_a
    assert_equal 2, departures.size

    sign_out
    sign_in(users(:two))
    visit ride_schedule_path(schedule)
    click_link "View departure on #{departures.first.departure_date.to_fs(:long)}"
    click_button "Request Seat"
    assert_text "Seat requested!"
    booking = Booking.find_by!(ride_post: departures.first, passenger: users(:two))

    sign_out
    sign_in(users(:one))
    visit ride_post_path(departures.first)
    click_button "Accept"
    assert_text "Booking accepted!"
    visit ride_schedule_path(schedule)
    within "#ride_post_#{departures.first.id}" do
      assert_text "2 seats available"
    end
    within "#ride_post_#{departures.second.id}" do
      assert_text "3 seats available"
    end
    assert booking.reload.accepted?
    click_button "Pause schedule"
    assert_text "Schedule paused"
    assert booking.reload.accepted?
    click_button "Resume schedule"
    assert_text "Schedule resumed"
  end

  test "a one-time ride can be published after switching back from regular" do
    sign_in(users(:one))
    visit new_ride_post_path
    page.execute_script("document.querySelector('#ride_post_origin_id').tomselect.setValue(arguments[0])", locations(:one).id.to_s)
    page.execute_script("document.querySelector('#ride_post_destination_id').tomselect.setValue(arguments[0])", locations(:two).id.to_s)
    fill_in "Departure Date", with: Date.tomorrow
    choose "Morning"
    fill_in "Available passenger seats", with: 2
    choose "Regular"
    click_button "Weekdays"
    choose "One-time"
    assert_difference "RidePost.count", 1 do
      assert_no_difference "RideSchedule.count" do
        click_button "Publish ride"
        assert_text "Ride post was successfully created."
      end
    end
    ride = users(:one).ride_posts.last
    assert_nil ride.ride_schedule_id
    assert_equal Date.tomorrow, ride.departure_date
    assert ride.morning?
  end

  test "regular validation and schedule editing use the shared controls on mobile" do
    sign_in(users(:one))
    page.driver.resize(320, 900)
    visit new_ride_post_path
    choose "Regular"
    choose "Exact Time"
    fill_in "Details & Preferences", with: "Keep these details"
    click_button "Publish regular ride"
    assert_checked_field "Regular"
    assert_field "Details & Preferences", with: "Keep these details"
    assert_selector "#ride_post_exact_departure_time_error"
    assert_selector "#ride_post_weekday_ids_error"
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    page.execute_script("document.querySelector('#ride_post_origin_id').tomselect.setValue(arguments[0])", locations(:one).id.to_s)
    page.execute_script("document.querySelector('#ride_post_destination_id').tomselect.setValue(arguments[0])", locations(:two).id.to_s)
    click_button "Weekdays"
    fill_in "Departure Time", with: "08:00"
    fill_in "Passenger seats per departure", with: 3
    check "Set an end date", allow_label_click: true
    fill_in "Repeat until", with: 3.weeks.from_now.to_date
    click_button "Publish regular ride"
    assert_text "Regular schedule saved"
    click_link "Edit schedule"
    assert_no_field "Regular"
    assert_field "Departure Time", with: "08:00"
    uncheck "Set an end date", allow_label_click: true
    click_button "Add one passenger seat"
    click_button "Save schedule"
    assert_text "Regular schedule saved"
    assert_equal 4, users(:one).ride_schedules.last.seats
    assert_nil users(:one).ride_schedules.last.end_date
  end

  private

  def sign_out
    find("button[data-navbar-target='trigger'][data-content-id='profile-content']").click
    click_on "Sign out"
    assert_current_path new_session_path
  end
end
