require "application_system_test_case"

class PassengerSeatsSystemTest < ApplicationSystemTestCase
  test "driver adjusts passenger seats or types a larger number without submitting" do
    visit new_session_path
    fill_in "Email Address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_current_path root_path
    visit new_ride_post_path
    assert_text "excludes the driver"
    fill_in "Available passenger seats", with: 1
    click_button "Remove one passenger seat"
    assert_field "Available passenger seats", with: "1"
    click_button "Add one passenger seat"
    assert_field "Available passenger seats", with: "2"
    fill_in "Available passenger seats", with: 12
    click_button "Add one passenger seat"
    assert_field "Available passenger seats", with: "13"
    assert_current_path new_ride_post_path
  end
end
