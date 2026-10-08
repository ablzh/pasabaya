require "application_system_test_case"

class MobileUxRemediationTest < ApplicationSystemTestCase
  test "passenger booking notices and actions stay centered within the card" do
    sign_in(users(:two))
    [ :pending, :accepted ].each do |status|
      bookings(:one).update_columns(status: Booking.statuses[status], accepted_at: status == :accepted ? 1.hour.ago : nil)
      [ 320, 1440 ].product(%w[light dark]).each do |width, theme|
        page.driver.resize(width, 900)
        visit ride_post_path(ride_posts(:one))
        page.execute_script("document.documentElement.classList.toggle('dark', arguments[0] === 'dark')", theme)
        within ".passenger-booking-content" do
          assert_text(status == :pending ? "Seat Requested" : "Seat Confirmed!")
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
          assert_in_delta (bounds["content"]["left"] + bounds["content"]["right"]) / 2, (child["left"] + child["right"]) / 2, 1
          assert_operator child["left"], :>=, bounds["content"]["left"] - 1
          assert_operator child["right"], :<=, bounds["content"]["right"] + 1
        end
        assert_not bounds["overflow"]
      end
    end
  end

  test "create and edit forms stack audience fields and retain large seat targets on phones" do
    sign_in(users(:one))
    [ new_ride_post_path, edit_ride_post_path(ride_posts(:one)) ].each do |path|
      [ 320, 390, 640 ].each do |width|
        page.driver.resize(width, 900)
        visit path
        assert_selector "#ride_post_origin_id-ts-control"
        geometry = page.evaluate_script <<~JS
          (() => {
            const rect = selector => document.querySelector(selector).getBoundingClientRect().toJSON();
            return {visibility: rect('#ride_post_visibility'), community: rect('#ride_post_community_id'),
              decrease: rect('button[aria-label="Remove one passenger seat"]'), increase: rect('button[aria-label="Add one passenger seat"]'),
              choices: getComputedStyle(document.querySelector('[data-controller="departure-choice"] > .grid')).gridTemplateColumns.split(' ').length,
              labelsFit: [...document.querySelectorAll('[data-controller="departure-choice"] > .grid > label')].every(label => label.scrollWidth <= label.clientWidth),
              hintsFit: [...document.querySelectorAll('[data-controller="departure-choice"] > .grid > label > span')].every(hint => hint.getBoundingClientRect().height <= parseFloat(getComputedStyle(hint).lineHeight) * 2 + 1),
              overflow: document.documentElement.scrollWidth > innerWidth};
          })()
        JS
        assert_operator geometry["community"]["top"], :>, geometry["visibility"]["bottom"]
        assert_equal width < 640 ? 2 : 3, geometry["choices"]
        assert geometry["labelsFit"], "Schedule labels must stay inside their option"
        assert geometry["hintsFit"], "Schedule hints should need at most two lines"
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
