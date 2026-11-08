require "application_system_test_case"

class SurveyBannersTest < ApplicationSystemTestCase
  test "survey banner is visible with correct CTA and opens form in new tab" do
    visit root_path

    assert_selector "#survey-banner", visible: true
    within "#survey-banner" do
      assert_text "Help us make Pasabaya better!"
      assert_text "Take our 10-minute survey."
      assert_selector "a[href*='docs.google.com/forms'][target='_blank']", text: "Take survey"
    end
  end

  test "survey banner dismiss hides it on current page but reappears on next page visit" do
    visit root_path
    assert_selector "#survey-banner", visible: true

    # Dismiss banner on root path
    find("#survey-banner-dismiss").click
    assert_no_selector "#survey-banner"

    # Navigate to another page via link
    click_link "Search"
    assert_current_path ride_posts_path
    assert_selector "#survey-banner", visible: true
  end

  test "survey banner adapts to mobile width" do
    page.current_window.resize_to(390, 844)
    visit root_path

    assert_selector "#survey-banner", visible: true
    within "#survey-banner" do
      assert_text "Help us make Pasabaya better!"
      assert_selector "#survey-banner-action", text: "Take survey"
      assert_selector "#survey-banner-dismiss"
    end
  end
end
