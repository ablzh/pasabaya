require "application_system_test_case"

class NavbarSystemTest < ApplicationSystemTestCase
  test "guest and authenticated navigation keep destinations reachable on phone and desktop" do
    [ 320, 1440 ].each do |width|
      page.driver.resize(width, 900)
      visit root_path
      within("nav.web-navigation") do
        assert_selector "a[href='#{ride_posts_path}']"
        assert_selector "a[href='#{new_ride_post_path}']"
        assert_no_selector "a[href='#{chats_path}']"
      end
      assert_selector "a[href='#{communities_path}']"
      assert_not page.evaluate_script("document.documentElement.scrollWidth > innerWidth")
    end

    sign_in
    [ 320, 1440 ].each do |width|
      page.driver.resize(width, 900)
      visit root_path
      within("nav.web-navigation") do
        assert_selector "a[href='#{chats_path}']"
        assert_selector "a[href='#{new_ride_post_path}']"
      end
      find("button[aria-label='Account menu']").click
      assert_selector "#profile-content[data-state='open']"
      bounds = page.evaluate_script("document.querySelector('#profile-content').getBoundingClientRect().toJSON()")
      assert_operator bounds["left"], :>=, 0
      assert_operator bounds["right"], :<=, width
      within("#profile-content") { find("a[href='#{user_path(users(:one))}']").click }
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
    assert_selector "#profile-content a:focus"
    visible_links = page.evaluate_script("[...document.querySelectorAll('#profile-content a')].filter(link => link.getClientRects().length).map(link => link.href)")
    assert_equal visible_links.first, page.evaluate_script("document.activeElement.href")
    page.driver.browser.keyboard.type(:down)
    assert_selector "#profile-content a:focus"
    assert_equal visible_links.second, page.evaluate_script("document.activeElement.href")
    page.driver.browser.keyboard.type(:End)
    assert page.evaluate_script("document.activeElement === [...document.querySelectorAll('#profile-content a')].filter(link => link.getClientRects().length).at(-1)")
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
