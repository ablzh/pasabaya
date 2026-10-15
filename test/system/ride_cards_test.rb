require "application_system_test_case"

class RideCardsTest < ApplicationSystemTestCase
  test "card surface author and keyboard open the trip while owner Edit opens editing" do
    ride = ride_posts(:one)
    sign_in(users(:one))

    board = ride_posts_path(origin_id: ride.origin_id)
    visit board
    within("#ride_post_#{ride.id}") do
      click_surface(find("p", text: "#{ride.user.first_name} #{ride.user.last_name}", exact_text: true))
    end
    assert_current_path ride_post_path(ride)

    visit board
    within("#ride_post_#{ride.id}") { click_surface(find("[role='img']")) }
    assert_current_path ride_post_path(ride)

    visit board
    within("#ride_post_#{ride.id}") do
      find("a[href='#{ride_post_path(ride)}']").send_keys(:enter)
    end
    assert_current_path ride_post_path(ride)

    visit board
    within("#ride_post_#{ride.id}") { click_link "Edit" }
    assert_current_path edit_ride_post_path(ride)

    visit board
    assert_no_selector "#ride_post_#{ride.id} a a"
    click_surface(find("#ride_post_#{ride.id}"), inset: 8)
    assert_current_path ride_post_path(ride)
  end
  private

  def click_surface(element, inset: nil)
    rect = element.evaluate_script("this.getBoundingClientRect().toJSON()")
    page.driver.browser.mouse.click(x: rect["left"] + (inset || rect["width"] / 2),
                                    y: rect["top"] + (inset || rect["height"] / 2))
  end
end
