require "application_system_test_case"

class TripHistoriesTest < ApplicationSystemTestCase
  test "history pagination preserves its section and stays usable through a Turbo refresh" do
    ride = ride_posts(:one)
    attributes = ride.attributes.except("id").merge("status" => RidePost.statuses[:completed], "departure_date" => 3.days.ago.to_date,
      "departure_time" => 3.days.ago, "created_at" => 4.days.ago.change(usec: 0))
    ids = RidePost.insert_all!(Array.new(25) { attributes.dup }, returning: %w[id]).rows.flatten.sort.reverse
    page.driver.resize(320, 844)
    sign_in(users(:one))
    visit trips_path
    assert_selector "#profile-history #ride_post_#{ids.first}"
    within("#history_page-pagination") { click_link "Next" }
    assert_current_path trips_path(history_page: 2)
    assert_equal "#profile-history", page.evaluate_script("location.hash")
    assert_selector "#profile-history #ride_post_#{ids.last}"
    assert_no_selector "#profile-history #ride_post_#{ids.first}"

    page.execute_script <<~JS
      window.observedMorphs = 0;
      document.addEventListener('turbo:morph', () => window.observedMorphs++);
      document.querySelector('#history_page-previous').focus();
      Turbo.renderStreamMessage('<turbo-stream action="refresh"></turbo-stream>');
    JS
    page.document.synchronize do
      raise Capybara::ExpectationNotMet unless page.evaluate_script("window.observedMorphs") > 0
    end
    assert_selector "#history_page-previous:focus"
    assert_selector "#profile-history #ride_post_#{ids.last}"
    page.driver.browser.keyboard.type(:Enter)
    assert_selector "#profile-history #ride_post_#{ids.first}"
    assert_no_selector "#profile-history #ride_post_#{ids.last}"
  end
end
