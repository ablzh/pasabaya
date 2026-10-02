require "application_system_test_case"

class HotwireNativeSystemTest < ApplicationSystemTestCase
  test "native presentation keeps login errors, trips and logout usable at phone width" do
    page.current_window.resize_to(390, 844)
    previous_headers = page.driver.headers
    page.driver.headers = { "User-Agent" => "Mozilla/5.0 Hotwire Native Android" }

    visit trips_path
    assert_title "Sign in"
    assert_selector "#native_navigation"
    assert_no_selector ".web-navigation"
    assert_no_selector ".web-footer"
    fill_in "Email Address", with: users(:one).email_address
    fill_in "Password", with: "wrong"
    click_button "Sign in"
    assert_text "Try another email address or password."
    assert_field "Email Address", with: users(:one).email_address

    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_current_path trips_path
    assert_title "My Trips"
    within "#native_navigation" do
      assert_link "Post a Ride"
      assert_link "Notifications"
      click_button "Sign out"
    end
    assert_current_path new_session_path
    assert_title "Sign in"
    assert_no_selector "#native_navigation button", text: "Sign out"
  ensure
    page.driver.headers = previous_headers if previous_headers
  end
end
