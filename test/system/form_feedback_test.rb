require "application_system_test_case"

class FormFeedbackSystemTest < ApplicationSystemTestCase
  test "ride corrections focus native and custom controls and clear only corrected fields" do
    sign_in
    visit new_ride_post_path
    fill_in "ride_post_notes", with: "Preserve my trip note"
    click_button "Publish ride"
    assert_selector "[data-form-errors-summary][data-controller='form-errors']"
    assert_selector "[data-form-errors-summary]:focus"
    assert_field "ride_post_seats", with: ""
    assert_selector "#ride_post_origin_id-ts-control[aria-invalid='true']"
    find("[data-form-errors-summary] li[data-error-for='ride_post_origin_id'] a").click
    assert_equal "ride_post_origin_id-ts-search", page.evaluate_script("document.activeElement.id")
    assert_selector "#ride_post_origin_id-ts-search[aria-invalid='true'][aria-describedby~='ride_post_origin_id_error']"
    page.execute_script("document.querySelector('#ride_post_origin_id').tomselect.setValue(arguments[0])", locations(:one).id.to_s)
    assert_no_selector "#ride_post_origin_id_error"
    assert_selector "#ride_post_destination_id_error"
    find("[data-form-errors-summary] a[href='#ride_post_seats']").click
    assert_equal "ride_post_seats", page.evaluate_script("document.activeElement.id")
    click_button "Add one passenger seat"
    assert_field "ride_post_seats", with: "1"
    assert_no_selector "#ride_post_seats_error"
    assert_no_selector "a[href='#ride_post_seats']"
    assert_selector "#ride_post_departure_date_error"
    page.execute_script("document.querySelector('#ride_post_destination_id').tomselect.setValue(arguments[0])", locations(:two).id.to_s)
    fill_in "ride_post_departure_date", with: Date.tomorrow
    choose "Morning"
    assert_no_selector "#ride_post_departure_choice_error"
    assert_no_selector "fieldset[aria-invalid='true']"
    assert_field "ride_post_notes", with: "Preserve my trip note"
    click_button "Publish ride"
    assert_text "Ride post was successfully created."
    assert RidePost.exists?(user: users(:one), notes: "Preserve my trip note", seats: 1, status: :active)
  end

  test "error summaries fit phone and desktop with valid focus targets" do
    sign_in
    [ 320, 1440 ].each do |width|
      page.driver.resize(width, 900)
      visit new_ride_post_path
      fill_in "ride_post_notes", with: "Retained note"
      click_button "Publish ride"
      assert_selector "[data-form-errors-summary] a"
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "#{width}px must not overflow"
      assert page.evaluate_script(<<~JS)
        [...document.querySelectorAll('[data-form-errors-summary] a')].every(link => {
          const input = document.getElementById(link.hash.slice(1));
          return input && (input.tomselect || input.getClientRects().length > 0);
        })
      JS
    end
  end

  test "credential feedback stays in the failed form and clears passwords after rejection" do
    sign_in
    page.driver.resize(320, 900)
    visit settings_profile_path
    fill_in "password_change_user_password_challenge", with: "incorrect"
    fill_in "password_change_user_password", with: "new-fixture-password"
    fill_in "password_change_user_password_confirmation", with: "different-fixture-password"
    click_button "Update Password"
    assert_selector "#password_change_user_password_challenge_error"
    assert_selector "#password_change_user_password_confirmation_error"
    assert_selector "[data-form-errors-summary]", count: 1
    assert_no_selector "#email_change_user_password_challenge[aria-invalid]"
    assert_selector "#password_change_user_password_challenge[aria-invalid='true'][aria-describedby~='password_change_user_password_challenge_error']"
    %w[password_challenge password password_confirmation].each { |field| assert_field "password_change_user_#{field}", with: "" }
    find("[data-form-errors-summary] a[href='#password_change_user_password_challenge']").click
    assert_equal "password_change_user_password_challenge", page.evaluate_script("document.activeElement.id")
    fill_in "password_change_user_password_challenge", with: "still incorrect"
    assert_selector "#password_change_user_password_challenge_error"
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    fill_in "password_change_user_password_challenge", with: "password"
    fill_in "password_change_user_password", with: "new-fixture-password"
    fill_in "password_change_user_password_confirmation", with: "new-fixture-password"
    click_button "Update Password"
    assert_text "Password changed successfully."
    assert users(:one).reload.authenticate("new-fixture-password")
  end

  private

  def sign_in
    visit new_session_path
    fill_in "Email Address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_selector "[data-notification-count]", visible: :all
    assert_current_path root_path
  end
end
