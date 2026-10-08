require "application_system_test_case"

class FormFeedbackSystemTest < ApplicationSystemTestCase
  test "ride corrections focus native and custom controls and clear only corrected fields" do
    sign_in
    visit new_ride_post_path
    fill_in "ride_post_notes", with: "Preserve my trip note"
    click_button "Publish ride"
    assert_selector "[data-form-errors-summary][data-controller='form-errors']"
    assert_equal "form-error-summary", page.evaluate_script("document.activeElement.classList[0]")
    assert_field "ride_post_seats", with: ""
    assert_invalid_style("#ride_post_origin_id-ts-control")
    click_link "Choose a departure city."
    assert_equal "ride_post_origin_id-ts-search", page.evaluate_script("document.activeElement.id")
    assert_selector "#ride_post_origin_id-ts-search[aria-invalid='true'][aria-describedby~='ride_post_origin_id_error']"
    page.execute_script("document.querySelector('#ride_post_origin_id').tomselect.setValue(arguments[0])", locations(:one).id.to_s)
    assert_no_selector "#ride_post_origin_id_error"
    assert_selector "#ride_post_destination_id_error"
    click_link "Enter the number of passenger seats."
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

  test "long error summaries fit each viewport and theme with valid focus targets" do
    sign_in
    [ 320, 390, 1440 ].product(%w[light dark]).each do |width, theme|
      page.driver.resize(width, 900)
      visit new_ride_post_path
      page.execute_script("localStorage.setItem('theme', arguments[0]); document.documentElement.classList.toggle('dark', arguments[0] === 'dark')", theme)
      fill_in "ride_post_notes", with: "Retained note"
      click_button "Publish ride"
      assert_selector "[data-form-errors-summary] li", minimum: 5
      assert_no_text "prohibited this post"
      assert_no_text "Remaining seats"
      assert_equal width, page.evaluate_script("window.innerWidth")
      assert_equal theme == "dark", page.evaluate_script("document.documentElement.classList.contains('dark')")
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "#{width}px #{theme} must not overflow"
      assert page.evaluate_script(<<~JS)
        [...document.querySelectorAll('[data-form-errors-summary] a')].every(link => {
          const input = document.getElementById(link.hash.slice(1));
          return input && (input.tomselect || input.getClientRects().length > 0);
        })
      JS
      capture_form("ride", width, theme)
    end
  end

  test "credential feedback stays in the failed form and clears passwords after rejection" do
    sign_in
    [ 320, 390, 1440 ].product(%w[light dark]).each do |width, theme|
      page.driver.resize(width, 900)
      visit settings_profile_path
      page.execute_script("localStorage.setItem('theme', arguments[0]); document.documentElement.classList.toggle('dark', arguments[0] === 'dark')", theme)
      fill_in "password_change_user_password_challenge", with: "incorrect"
      fill_in "password_change_user_password", with: "new-fixture-password"
      fill_in "password_change_user_password_confirmation", with: "different-fixture-password"
      click_button "Update Password"
      assert_text "Your current password is incorrect."
      assert_text "The passwords don’t match. Re-enter your new password."
      assert_selector "[data-form-errors-summary]", count: 1
      assert_equal width, page.evaluate_script("window.innerWidth")
      assert_equal theme == "dark", page.evaluate_script("document.documentElement.classList.contains('dark')")
      assert_no_selector "#email_change_user_password_challenge[aria-invalid]"
      assert_invalid_style("#password_change_user_password_challenge")
      %w[password_challenge password password_confirmation].each { |field| assert_field "password_change_user_#{field}", with: "" }
      click_link "Your current password is incorrect."
      assert_equal "password_change_user_password_challenge", page.evaluate_script("document.activeElement.id")
      fill_in "password_change_user_password_challenge", with: "still incorrect"
      assert_selector "#password_change_user_password_challenge_error", text: "Your current password is incorrect."
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
      capture_form("password", width, theme)
    end
    fill_in "password_change_user_password_challenge", with: "password"
    fill_in "password_change_user_password", with: "new-fixture-password"
    fill_in "password_change_user_password_confirmation", with: "new-fixture-password"
    click_button "Update Password"
    assert_text "Password changed successfully."
    assert users(:one).reload.authenticate("new-fixture-password")
  end

  private

  def assert_invalid_style(selector)
    assert page.evaluate_script(<<~JS, selector), "Invalid controls must have a visible red border or outline"
      (() => {
        const element = document.querySelector(arguments[0]);
        const reference = document.createElement('span');
        reference.style.borderColor = document.documentElement.classList.contains('dark') ? 'var(--color-red-400)' : 'var(--color-red-600)';
        document.body.append(reference);
        const expected = getComputedStyle(reference).borderTopColor;
        const styles = getComputedStyle(element);
        const visible = styles.borderTopColor === expected || (styles.outlineColor === expected && styles.outlineStyle !== 'none' && parseFloat(styles.outlineWidth) > 0);
        reference.remove();
        return visible;
      })()
    JS
  end

  def capture_form(name, width, theme)
    # Capture the current document after Turbo's view-transition animation finishes.
    page.document.synchronize do
      raise Capybara::ExpectationNotMet if page.evaluate_script("document.getAnimations().some(animation => animation.playState === 'running')")
    end
    page.save_screenshot(Rails.root.join("docs/qa/form-feedback-#{name}-#{width}-#{theme}.png"), full: true)
  end

  def sign_in
    visit new_session_path
    fill_in "Email Address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_selector "[data-notification-count]", visible: :all
    assert_current_path root_path
  end
end
