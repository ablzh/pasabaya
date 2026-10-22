require "application_system_test_case"

class NavbarSystemTest < ApplicationSystemTestCase
  test "guest navigation links preserve keyboard focus across a morph and activate with Enter" do
    page.driver.resize(320, 844)
    visit root_path
    find("#navbar-login").execute_script("this.focus()")
    page.execute_script <<~JS
      window.observedMorphs = 0;
      document.addEventListener('turbo:morph', () => window.observedMorphs++);
      Turbo.renderStreamMessage('<turbo-stream action="refresh"></turbo-stream>');
    JS
    page.document.synchronize do
      raise Capybara::ExpectationNotMet unless page.evaluate_script("window.observedMorphs") > 0
    end
    assert_selector "a#navbar-login:focus"
    page.driver.browser.keyboard.type(:Tab)
    assert_selector "a#navbar-signup:focus"
    page.driver.browser.keyboard.type(:Enter)
    assert_current_path sign_up_path

    find("#navbar-login").execute_script("this.focus()")
    page.driver.browser.keyboard.type(:Enter)
    assert_current_path new_session_path
  end

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

    sign_in(users(:one))
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
    sign_in(users(:one))
    page.driver.resize(320, 900)
    visit root_path
    find("button[aria-label='Account menu']").click
    within("#profile-content") { click_link "Hubs" }
    assert_current_path communities_path
  end

  test "profile menu supports keyboard focus escape outside dismissal and live resizing" do
    sign_in(users(:one))
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

  test "mobile navigation and chat actions have at least 44px targets" do
    bookings(:one).update_columns(status: Booking.statuses[:accepted], accepted_at: Time.current)
    ride_posts(:one).chat_messages.create!(user: users(:two), body: "Unread coordination message")
    sign_in(users(:one))
    resize_and_visit(320, root_path)
    page.execute_script("const style = document.createElement('style'); style.textContent = 'html {overflow-y:scroll;scrollbar-gutter:stable} ::-webkit-scrollbar {width:15px}'; document.head.append(style)")
    assert_selector ".unread-chats-badge", text: "1"
    assert_document_contained
    targets = page.evaluate_script("[...document.querySelectorAll('.web-navigation [data-navbar-target=menu] > li > a, .web-navigation [data-navbar-target=menu] > li > button')].filter(el => el.getClientRects().length).map(el => ({text:el.textContent, width:el.getBoundingClientRect().width,height:el.getBoundingClientRect().height}))")
    targets.each do |target|
      %w[width height].each { |dimension| assert_operator target[dimension], :>=, 44, target["text"] }
    end
    resize_and_visit(390, ride_post_path(ride_posts(:one), tab: "chat"))
    [ "button[aria-label='Back to trip']", "#chat_message_form button" ].each do |selector|
      rect = find(selector).evaluate_script("this.getBoundingClientRect().toJSON()")
      %w[width height].each { |dimension| assert_operator rect[dimension], :>=, 44 }
    end
  end
end
