# frozen_string_literal: true

require "application_system_test_case"

class AdminModerationSystemTest < ApplicationSystemTestCase
  test "administrator reads feedback and records a decision and its reversal with history" do
    admin = User.create!(email_address: "browser-moderator@example.test", password: "password",
      first_name: "Browser", last_name: "Moderator", admin: true)
    driver = users(:one)
    passenger = users(:two)
    ride = ride_posts(:one)
    bookings(:one).update_columns(status: Booking.statuses[:accepted], accepted_at: 3.hours.ago)
    ride.update_columns(departure_time: 2.hours.ago, expected_arrival_at: 1.hour.ago)
    review = TripReview.create!(ride_post: ride, reporter: driver, reported_user: passenger,
      outcome: :passenger_no_show, notes: "Waited at the pickup point for twenty minutes.")
    incident = NoShowIncident.create!(ride_post: ride, user: passenger, occurred_at: 2.hours.ago)

    visit new_session_path
    fill_in "Email Address", with: admin.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_current_path root_path
    find("button[aria-label='Account menu']").click
    click_link "Administration"
    assert_current_path admin_root_path
    click_link "Trip reviews"
    click_link "Review ##{review.id} · Passenger no show"
    assert_text "Waited at the pickup point for twenty minutes."
    click_link "Open incident ##{incident.id}"
    assert_current_path admin_no_show_incident_path(incident)
    assert_text "Booking history"
    fill_in "Decision reason", with: "Confirmed against the pickup reports."
    select "Confirm no-show", from: "Decision"
    click_button "Save decision"
    assert_text "Decision saved."
    within "#decision-history" do
      assert_text "Pending → Upheld"
      assert_text "Confirmed against the pickup reports."
    end

    fill_in "Decision reason", with: "Reconsidered after correcting the agreed meeting point."
    select "Dismiss report", from: "Decision"
    click_button "Save decision"
    within "#decision-history" do
      assert_text "Upheld → Dismissed"
      assert_text "Pending → Upheld"
    end
    assert incident.reload.dismissed?
    assert_equal 2, incident.decisions.count
    assert_equal 2, Notification.where(recipient: passenger, event_name: "incident.resolved").count

    page.driver.browser.resize(width: 390, height: 844)
    assert_selector "h1", text: "Incident ##{incident.id}"
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "Admin case should fit a mobile viewport"
  end
end
