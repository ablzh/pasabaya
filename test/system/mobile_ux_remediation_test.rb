require "application_system_test_case"

class MobileUxRemediationTest < ApplicationSystemTestCase
  test "passenger booking actions remain contained on phone and desktop" do
    sign_in(users(:two))
    [ :pending, :accepted ].each do |status|
      bookings(:one).update_columns(status: Booking.statuses[status], accepted_at: status == :accepted ? 1.hour.ago : nil)
      [ 320, 1440 ].each do |width|
        page.driver.resize(width, 900)
        visit ride_post_path(ride_posts(:one))
        within ".passenger-booking-content" do
          assert_button(status == :pending ? "Cancel Request" : "Cancel Booking")
        end
        bounds = page.evaluate_script <<~JS
          (() => {
            const content = document.querySelector('.passenger-booking-content');
            const rect = el => el.getBoundingClientRect().toJSON();
            return {content: rect(content), children: [...content.children].map(rect), overflow: document.documentElement.scrollWidth > innerWidth};
          })()
        JS
        bounds["children"].each do |child|
          assert_operator child["left"], :>=, bounds["content"]["left"] - 1
          assert_operator child["right"], :<=, bounds["content"]["right"] + 1
        end
        assert_not bounds["overflow"]
      end
    end
  end

  test "create and edit forms keep schedule labels visible and seat targets usable on phones" do
    sign_in(users(:one))
    [ new_ride_post_path, edit_ride_post_path(ride_posts(:one)) ].each do |path|
      [ 320, 640 ].each do |width|
        page.driver.resize(width, 900)
        visit path
        assert_selector "#ride_post_origin_id-ts-control"
        geometry = page.evaluate_script <<~JS
          (() => {
            const rect = selector => document.querySelector(selector).getBoundingClientRect().toJSON();
            return {decrease: rect('button[aria-label="Remove one passenger seat"]'), increase: rect('button[aria-label="Add one passenger seat"]'),
              labelsFit: [...document.querySelectorAll('[data-controller="departure-choice"] label')].every(label => label.scrollWidth <= label.clientWidth),
              overflow: document.documentElement.scrollWidth > innerWidth};
          })()
        JS
        assert geometry["labelsFit"], "Schedule labels must stay inside their option"
        %w[decrease increase].each do |control|
          %w[width height].each { |dimension| assert_operator geometry[control][dimension], :>=, 44 }
        end
        assert_not geometry["overflow"]
      end
    end
  end

  private

  def sign_in(user)
    visit new_session_path
    fill_in "Email Address", with: user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_current_path root_path
  end
end
