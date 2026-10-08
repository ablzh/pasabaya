require "application_system_test_case"

class ResponsiveFlowsTest < ApplicationSystemTestCase
  test "navigation and affected forms and details fit every requested width and theme" do
    widths = [ 320, 360, 390, 768, 1440 ]
    widths.product(%w[light dark]).each do |width, theme|
      viewport(width, theme)
      visit root_path
      check_navigation(width, authenticated: false)
    end
    visit new_session_path
    fill_in "Email Address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_current_path root_path

    offer = ride_posts(:one)
    offer.update_columns(expected_arrival_at: offer.departure_time + 1.day)
    bookings(:one).update_columns(status: Booking.statuses[:accepted])
    offer.chat_messages.create!(user: users(:two), body: "See you at pickup")
    cities = Location.all.index_by(&:name)
    draft = users(:one).ride_posts.create!(post_type: :offering, status: :draft,
                                          origin: cities.fetch("Manila"), destination: cities.fetch("Makati"), seats: 2)
    widths.product(%w[light dark]).each do |width, theme|
      viewport(width, theme)
      visit root_path
      check_navigation(width, authenticated: true)
      visit settings_profile_path
      assert_selector "#email_change_user_password_challenge"
      assert_fits
      visit new_ride_post_path
      assert_selector "#ride_post_origin_id-ts-control"
      assert_selector "label", text: "Available passenger seats", exact_text: true
      assert_button "Save draft"
      visit ride_post_path(offer)
      assert_link "Maria Clara", href: user_path(users(:two))
      assert_text offer.expected_arrival_at.strftime("%a, %b %d, %Y")
      assert_fits
      visit ride_post_path(draft)
      assert_text "Unpublished — edit to publish"
      assert_no_link "Review Trip / Report No-Show"
      assert_fits
    end
  end

  test "route keyboard order is From To swap date search" do
    visit ride_posts_path
    assert_selector "#origin_id-ts-control"
    find("label[for=origin_id-ts-control]").click
    assert_selector "#origin_id + .ts-wrapper .ts-dropdown input:focus"
    page.driver.browser.keyboard.type(:Escape)
    assert_no_selector ".ts-dropdown", visible: true
    page.driver.browser.keyboard.type(:Tab)
    assert_selector "#destination_id + .ts-wrapper .ts-dropdown input:focus"
    find("#destination_id + .ts-wrapper .ts-dropdown input").send_keys(:escape)
    assert_no_selector ".ts-dropdown", visible: true
    # Tom Select's dropdown search and the native date segments have internal stops.
    6.times do
      page.driver.browser.keyboard.type(:Tab)
      break if page.evaluate_script("document.activeElement.getAttribute('aria-label')") == "Swap Origin and Destination"
    end
    assert_equal "Swap Origin and Destination", page.evaluate_script("document.activeElement.getAttribute('aria-label')")
    page.driver.browser.keyboard.type(:Tab)
    assert_equal "departure_date", page.evaluate_script("document.activeElement.id")
    8.times do
      page.driver.browser.keyboard.type(:Tab)
      break if page.evaluate_script("document.activeElement.textContent.trim() == 'Search Rides' || document.activeElement.closest('button')?.textContent.trim() == 'Search Rides'")

      assert_equal "departure_date", page.evaluate_script("document.activeElement.id")
    end
    assert_equal "Search Rides", page.evaluate_script("document.activeElement.textContent.trim()")
    focus = page.evaluate_script <<~JS
      (() => {
        const button = document.activeElement;
        const panel = button.closest('[data-search-panel]').getBoundingClientRect();
        const rect = button.getBoundingClientRect();
        const style = getComputedStyle(button);
        return {visible: button.matches(':focus-visible'), width: parseFloat(style.outlineWidth), offset: parseFloat(style.outlineOffset),
          gutter: Math.min(rect.left - panel.left, panel.right - rect.right, panel.bottom - rect.bottom)};
      })()
    JS
    assert focus["visible"]
    assert_operator focus["width"], :>=, 2
    assert_operator focus["gutter"], :>, focus["width"] + focus["offset"]
  end

  private

  def viewport(width, theme)
    page.driver.resize(width, width < 768 ? 844 : 1024)
    # Persist the requested theme so each subsequent Turbo visit uses the same palette.
    visit root_path
    page.execute_script("localStorage.setItem('theme', '#{theme}')")
  end

  def check_navigation(width, authenticated:)
    within("nav.web-navigation") do
      assert_no_selector "button[aria-label='Navigation menu']"
      assert_link "Search", href: ride_posts_path
      assert_link(width < 640 ? "Post" : "Add a ride", href: new_ride_post_path)
      if authenticated
        assert_link "Chats", href: chats_path
        assert_selector "a[href='#{chats_path}'] [data-chat-unread-count] span", text: "1"
      else
        assert_no_link "Chats", href: chats_path
      end
      if width < 640
        assert_no_link "Hubs"
      else
        assert_link "Hubs", href: communities_path
      end
    end
    if !authenticated && width < 640
      within("footer") { assert_link "Hubs", href: communities_path }
    end
    if authenticated
      assert_selector "[data-notification-count] span"
      page.execute_script('document.querySelector("button[aria-label=\"Account menu\"]").focus()')
      page.driver.browser.keyboard.type(:Enter)
      assert_selector '#profile-content[data-state="open"]'
      assert_menu_fits("#profile-content")
      within("#profile-content") do
        if width < 640
          assert_link "Hubs", href: communities_path
        else
          assert_no_link "Hubs"
        end
        assert_no_link "Search"
        assert_no_link "Chats"
      end
      page.driver.browser.keyboard.type(:Escape)
    end
    assert_equal 32, page.evaluate_script("document.querySelector('nav img').getBoundingClientRect().width")
    assert_operator page.evaluate_script("document.querySelector('nav').getBoundingClientRect().height"), :<=, 56
    assert_fits
  end

  def assert_menu_fits(selector)
    page.document.synchronize do
      rect = page.evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().toJSON()")
      raise Capybara::ExpectationNotMet unless rect["left"] >= 0 && rect["right"] <= page.evaluate_script("innerWidth")
    end
    rect = page.evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().toJSON()")
    assert_operator rect["left"], :>=, 0
    assert_operator rect["right"], :<=, page.evaluate_script("innerWidth")
  end

  def assert_fits
    assert_not page.evaluate_script("document.documentElement.scrollWidth > innerWidth"), "Page overflows viewport"
  end
end
