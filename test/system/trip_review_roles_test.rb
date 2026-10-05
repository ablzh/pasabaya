require "application_system_test_case"

class TripReviewRolesTest < ApplicationSystemTestCase
  test "changing the reviewed participant changes the available no show category" do
    ride = ride_posts(:one)
    passenger = users(:two)
    other = User.create!(email_address: "other-reviewee@example.test", password: "password", first_name: "Other", last_name: "Passenger")
    bookings(:one).update_columns(status: Booking.statuses[:accepted], accepted_at: 2.hours.ago)
    Booking.create!(ride_post: ride, passenger: other, status: :accepted)
    ride.update_columns(departure_time: 1.hour.ago, expected_arrival_at: Time.current)
    visit new_session_path
    fill_in "Email Address", with: passenger.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_current_path root_path

    visit new_ride_post_review_path(ride, reported_user_id: ride.user_id)
    assert_selector "option[value='passenger_no_show'][disabled]", visible: :all
    select "Driver did not show up (No-show)", from: "Trip Outcome"
    select "Other Passenger", from: "Participant to Review"
    assert_selector "option[value='driver_no_show'][disabled]", visible: :all
    assert_select "Trip Outcome", selected: "Ride completed smoothly"
    select "Passenger did not show up (No-show)", from: "Trip Outcome"
    click_button "Submit Report"
    assert_text "Thank you for submitting your trip review."
    assert TripReview.exists?(reporter: passenger, reported_user: other, outcome: :passenger_no_show)
  end
end
