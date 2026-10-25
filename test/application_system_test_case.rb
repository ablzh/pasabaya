# frozen_string_literal: true

require "test_helper"
require "capybara/cuprite"
require_relative "test_helpers/browser_presentation_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include BrowserPresentationHelper

  Capybara.default_max_wait_time = 5

  driven_by :cuprite, screen_size: [ 1400, 1400 ], options: {
    process_timeout: 15,
    timeout: 10,
    browser_options: { "no-sandbox" => nil }
  }

  private

  def sign_in(user)
    visit new_session_path
    fill_in "Email Address", with: user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_signed_in
  end

  def assert_signed_in(expected_path: root_path)
    assert_selector "html:not([data-turbo-preview]) #account-notification-count", visible: :all
    assert_current_path expected_path
  end
end
