require "application_system_test_case"

class HomeNavigationsTest < ApplicationSystemTestCase
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
      assert_document_contained
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
end
