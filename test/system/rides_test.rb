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
      click_on "Show", match: :first
    end

    assert_selector "h1", text: /Manila\s+→\s+Makati/
    assert_text "Heading to Manila early morning."
    assert_text "3"

    # 3. Create a ride while signed in
    click_on "Add a ride"
    assert_current_path new_ride_post_path

    find("#ride_post_origin_id-ts-control").click
    find(".ts-dropdown .option", text: "Makati").click

    find("#ride_post_destination_id-ts-control").click
    find(".ts-dropdown .option", text: "Manila").click

    fill_in "Seats", with: 4
    fill_in "Details & Preferences", with: "Carpooling together tomorrow morning, 4 seats open."

    click_button "Save Post"

    # Assert user-visible outcomes of creation
    assert_text "Ride offer saved as a private draft."
    assert_selector "h1", text: /Makati\s+→\s+Manila/
    assert_text "4"
    assert_text "Carpooling together tomorrow morning, 4 seats open."
    assert_link "Edit"
  end
end
