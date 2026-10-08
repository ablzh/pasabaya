require "application_system_test_case"
require_relative "../test_helpers/rate_limit_test_helper"

class AbuseProtectionSystemTest < ApplicationSystemTestCase
  include RateLimitTestHelper

  test "signup honeypot is hidden and an immediate Turbo submission succeeds" do
    visit sign_up_path
    assert_selector "input[name='user[contact_reference]']", visible: :hidden
    fill_in "First Name", with: "Browser"
    fill_in "Last Name", with: "Passenger"
    fill_in "Email Address", with: "browser-signup@example.test"
    fill_in "user_password", with: "password123"
    fill_in "Confirm Password", with: "password123"
    check "user_registration_acceptance"
    click_button "Create Account & Log In"

    assert_current_path root_path
    assert_text "Your account was successfully created."
    assert User.exists?(email_address: "browser-signup@example.test")
  end

  test "chat throttling shows a persistent warning and preserves the unsent draft" do
    ride = ride_posts(:one)
    passenger = users(:two)
    bookings(:one).update_columns(status: Booking.statuses[:accepted], accepted_at: Time.current)

    with_rate_limit_cache do
      visit new_session_path
      fill_in "Email Address", with: passenger.email_address
      fill_in "Password", with: "password"
      click_button "Sign in"
      assert_current_path root_path
      visit ride_post_path(ride, tab: "chat")

      30.times do |index|
        text = "Coordination message #{index}"
        fill_in "Coordination message", with: text
        click_button "Send"
        assert_selector ".chat-message", text: text
      end

      fill_in "Coordination message", with: "Keep this draft"
      click_button "Send"
      assert_text "Too many messages. Please wait before trying again."
      assert_field "Coordination message", with: "Keep this draft"
      assert_no_selector ".chat-message", text: "Keep this draft"
      assert_not ChatMessage.exists?(user: passenger, body: "Keep this draft")
    end
  end
end
