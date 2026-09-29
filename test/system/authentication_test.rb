# frozen_string_literal: true

require "application_system_test_case"

class AuthenticationSystemTest < ApplicationSystemTestCase
  test "user signs in, accesses authenticated areas, and signs out" do
    user = users(:one)

    visit root_url
    assert_text "Carpooling for the Community"

    click_on "Login"
    assert_current_path new_session_path

    fill_in "Email Address", with: user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"

    assert_current_path root_path
    assert_no_link "Login"
    assert_no_link "Signup"

    # Navigate to post a ride while authenticated
    click_on "Add a ride"
    assert_current_path new_ride_post_path
    assert_text "Post a Ride"

    # Profile dropdown menu toggles via Stimulus and allows sign out via Turbo
    find("button[data-navbar-target='trigger'][data-content-id='profile-content']").click
    click_on "Sign out"

    assert_current_path new_session_path
    assert_link "Sign up"
  end
end
