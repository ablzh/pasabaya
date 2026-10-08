require "application_system_test_case"

class NavbarSystemTest < ApplicationSystemTestCase
  test "profile menu first opens directly beneath its trigger and remains responsive" do
    sign_in
    page.driver.resize(1440, 900)
    visit root_path
    assert_selector "button[aria-label='Account menu']"
    placement = page.evaluate_script <<~JS
      (() => {
        const trigger = document.querySelector('button[aria-label="Account menu"]');
        trigger.click();
        const menu = document.querySelector('[data-navbar-target="viewport"]').getBoundingClientRect();
        const button = trigger.getBoundingClientRect();
        return { right: menu.right, triggerRight: button.right, top: menu.top, triggerBottom: button.bottom };
      })()
    JS
    assert_in_delta placement["triggerRight"], placement["right"], 8
    assert_operator placement["top"], :>=, placement["triggerBottom"]
    assert_selector "#profile-content[data-state='open']"
    [ 320, 390, 1440 ].each do |width|
      page.driver.resize(width, 900)
      visit root_path
      find("button[aria-label='Account menu']").click
      assert_selector "#profile-content[data-state='open']"
      bounds = page.evaluate_script("document.querySelector('#profile-content').getBoundingClientRect().toJSON()")
      assert_operator bounds["left"], :>=, 0
      assert_operator bounds["right"], :<=, width
      click_link "Profile"
      assert_current_path user_path(users(:one))
    end
  end

  test "mobile hubs link opens from the account menu" do
    sign_in
    page.driver.resize(320, 900)
    visit root_path
    find("button[aria-label='Account menu']").click
    within("#profile-content") { click_link "Hubs" }
    assert_current_path communities_path
  end

  test "profile menu supports keyboard focus escape outside dismissal and live resizing" do
    sign_in
    page.driver.resize(1440, 900)
    visit root_path
    trigger = find("button[aria-label='Account menu']")
    trigger.execute_script("this.focus()")
    page.driver.browser.keyboard.type(:down)
    assert_selector "#profile-content a[href='#{user_path(users(:one))}']:focus"
    page.driver.browser.keyboard.type(:down)
    assert_selector "#profile-content a[href='#{settings_profile_path}']:focus"
    page.driver.browser.keyboard.type(:down)
    assert_selector "#profile-content a[href='#{notifications_path}']:focus"
    page.driver.browser.keyboard.type(:down)
    assert_selector "#profile-content a[href='#{session_path}']:focus"
    page.driver.browser.keyboard.type(:End)
    assert_selector "#profile-content a[href='#{session_path}']:focus"
    page.driver.browser.keyboard.type(:Escape)
    assert_selector "button[aria-label='Account menu']:focus"
    assert_selector "#profile-content[data-state='closed']", visible: :all
    page.driver.browser.keyboard.type(:Enter)
    assert_selector "#profile-content[data-state='open']"
    page.driver.resize(320, 900)
    page.document.synchronize do
      bounds = page.evaluate_script("document.querySelector('#profile-content').getBoundingClientRect().toJSON()")
      raise Capybara::ExpectationNotMet unless bounds["left"] >= 0 && bounds["right"] <= 320
    end
    find("footer").click
    assert_selector "#profile-content[data-state='closed']", visible: :all
    trigger.execute_script("this.focus()")
    page.driver.browser.keyboard.type(:down)
    page.execute_script("document.querySelector('main a[href]').focus()")
    assert_selector "#profile-content[data-state='closed']", visible: :all
  end

  private

  def sign_in
    visit new_session_path
    fill_in "Email Address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_current_path root_path
  end
end
