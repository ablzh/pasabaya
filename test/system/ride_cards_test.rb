require "application_system_test_case"

class RideCardsTest < ApplicationSystemTestCase
  test "card surface author and keyboard open the trip while owner Edit opens editing" do
    ride = ride_posts(:one)
    visit new_session_path
    fill_in "Email Address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_current_path root_path

    board = ride_posts_path(origin_id: ride.origin_id)
    visit board
    within("#ride_post_#{ride.id}") do
      assert_no_link "Show"
      click_surface(find("p", text: "#{ride.user.first_name} #{ride.user.last_name}", exact_text: true))
    end
    assert_current_path ride_post_path(ride)

    visit board
    within("#ride_post_#{ride.id}") { click_surface(find(".h-9.w-9")) }
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
  test "cards in a row have aligned footers and concise two-line previews" do
    first = ride_posts(:one)
    second = ride_posts(:two)
    first.update_columns(notes: "Short note")
    second.update_columns(origin_id: first.origin_id, destination_id: first.destination_id, notes: "Long details " * 20)
    page.driver.resize(1440, 1024)
    visit ride_posts_path(origin_id: first.origin_id)
    assert_selector "#ride_posts > div", count: 2

    layout = page.evaluate_script <<~JS
      Array.from(document.querySelectorAll('#ride_posts > div')).map(wrapper => {
        const card = wrapper.firstElementChild;
        const footer = card.lastElementChild;
        const preview = card.querySelector('p.line-clamp-2');
        return { height: card.getBoundingClientRect().height, footerTop: footer.getBoundingClientRect().top,
                 previewLength: preview.textContent.trim().length, clamp: getComputedStyle(preview).webkitLineClamp };
      })
    JS
    assert_in_delta layout[0]["height"], layout[1]["height"], 1
    assert_in_delta layout[0]["footerTop"], layout[1]["footerTop"], 1
    layout.each do |entry|
      assert_operator entry["previewLength"], :<=, 110
      assert_equal "2", entry["clamp"]
    end
    page.driver.resize(390, 844)
    assert_not page.evaluate_script("document.documentElement.scrollWidth > innerWidth")
  end

  private

  def click_surface(element, inset: nil)
    rect = element.evaluate_script("this.getBoundingClientRect().toJSON()")
    page.driver.browser.mouse.click(x: rect["left"] + (inset || rect["width"] / 2),
                                    y: rect["top"] + (inset || rect["height"] / 2))
  end
end
