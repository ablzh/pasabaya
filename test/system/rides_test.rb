# frozen_string_literal: true

require "application_system_test_case"

class RidesTest < ApplicationSystemTestCase
  test "search for a ride, open a result, and create a ride while signed in" do
    user = users(:one)

    # Sign in
    visit new_session_path
    fill_in "Email Address", with: user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_current_path root_path

    # 1. Search for a ride
    click_link "Search"
    assert_current_path ride_posts_path

    click_button "Search Rides"

    # Assert search results show the matching ride and allow opening a driver offer
    assert_selector "#ride_posts article, #ride_posts [id^='ride_post_']", text: "Manila → Makati"
    assert_text "Heading to Manila early morning."

    # 2. Open a result
    within "#ride_posts" do
      find("a[aria-label='View ride: Manila to Makati']").click
    end

    assert_selector "h1", text: /Manila\s+→\s+Makati/
    assert_text "Heading to Manila early morning."
    assert_text "3"
    assert_text "YOUR TRIP NOTES"
    assert_no_text "VIEW PROFILE & REVIEWS"

    # 3. Create a ride while signed in
    click_on "Add a ride"
    assert_current_path new_ride_post_path

    find("#ride_post_origin_id-ts-control").click
    find(".ts-dropdown .option", text: "Makati").click

    find("#ride_post_destination_id-ts-control").click
    find(".ts-dropdown .option", text: "Manila").click

    fill_in "Available passenger seats", with: 4
    fill_in "Details & Preferences", with: "Carpooling together tomorrow morning, 4 seats open."

    click_button "Save draft"

    # Assert user-visible outcomes of creation
    assert_text "Ride saved as a private draft."
    assert_selector "h1", text: /Makati\s+→\s+Manila/
    assert_text "4"
    assert_text "Carpooling together tomorrow morning, 4 seats open."
    assert_link "Edit"
    click_link "Edit Post"
    fill_in "Departure Date", with: 3.days.from_now.to_date
    choose "Exact Time"
    fill_in "Departure Time", with: "09:00"
    click_button "Save draft"
    assert_text "Unpublished — edit to publish"
    click_link "Edit Post"
    assert_field "Expected Arrival Time (optional)", with: ""
    click_button "Publish ride"
    assert_text "Accepting requests"
  end
end
