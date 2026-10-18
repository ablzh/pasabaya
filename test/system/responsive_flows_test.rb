require "application_system_test_case"

class ResponsiveFlowsTest < ApplicationSystemTestCase
  test "homepage guides work on phone and desktop and preserve regular ride intent through sign in" do
    [ [ 320, "light" ], [ 1440, "dark" ] ].each do |width, theme|
      page.driver.resize(width, width < 768 ? 844 : 1024)
      visit root_path
      page.execute_script("localStorage.setItem('theme', arguments[0]); document.documentElement.classList.toggle('dark', arguments[0] === 'dark'); document.documentElement.style.colorScheme = arguments[0]", theme)
      assert_selector "#origin_id-ts-control"
      within "#how-to-start" do
        assert_text "Look at passenger profiles and accept or decline each request."
        assert_link "Offer a Ride", href: new_ride_post_path
        assert_text "Your seat is confirmed when the driver accepts."
      end
      assert_selector "#home-chat figure"
      within "#home-apps" do
        assert_text /coming soon/i
        assert_text "iOS"
        assert_text "Android"
      end
      assert_fits
      assert page.evaluate_script("[...document.querySelectorAll('#main_content h1, #main_content h2, #main_content h3, #main_content p, #main_content li, #main_content figcaption')].filter(element => element.getClientRects().length).every(element => element.scrollWidth <= element.clientWidth + 1)"), "Homepage text must fit without clipping"

      find("#home_passenger_start").click
      assert_current_path ride_posts_path
      assert_selector "#origin_id-ts-control"
    end

    visit root_path
    find("#home_regular_ride").click
    assert_current_path new_session_path
    fill_in "Email Address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_signed_in(expected_path: new_ride_post_path(ride_type: "regular"))
    assert_selector "#ride_type_regular:checked"
  end

  test "settings ride forms and details fit phone and desktop widths" do
    sign_in(users(:one))

    offer = ride_posts(:one)
    bookings(:one).update_columns(status: Booking.statuses[:accepted])
    [ 320, 1440 ].each do |width|
      page.driver.resize(width, width < 768 ? 844 : 1024)
      visit settings_profile_path
      assert_selector "#email_change_user_password_challenge"
      assert_fits
      visit new_ride_post_path
      assert_selector "#ride_post_origin_id-ts-control"
      assert_button "Save draft"
      assert_fits
      visit ride_post_path(offer)
      assert_link "Maria Clara", href: user_path(users(:two))
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
      break if page.evaluate_script("document.activeElement.matches('[data-search-panel] button[type=submit]')")

      assert_equal "departure_date", page.evaluate_script("document.activeElement.id")
    end
    assert_selector "[data-search-panel] button[type=submit]:focus"
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
    assert_operator focus["width"], :>, 0
    assert_operator focus["gutter"], :>, focus["width"] + focus["offset"]
  end

  private

  def assert_fits
    assert_not page.evaluate_script("document.documentElement.scrollWidth > innerWidth"), "Page overflows viewport"
  end
end
