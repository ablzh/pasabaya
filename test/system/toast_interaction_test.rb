require "application_system_test_case"

class ToastInteractionTest < ApplicationSystemTestCase
  test "toast stacks fit phone and desktop and support expansion dismissal and actions" do
    page.driver.resize(320, 844)
    visit root_path
    page.execute_script <<~JS
      Stimulus.getControllerForElementAndIdentifier(document.getElementById('toast-container'), 'toast').autoDismissDurationValue = 60000;
      window.toast('Saved.', {type: 'success'});
      window.toast('A multiline notification with enough detail to wrap across several lines on a narrow phone. Check the route and departure before requesting a seat.', {description: 'Optional description also wraps.', type: 'info'});
      window.toast('Maria requested a seat on your ride.', {type: 'info', action: {label: 'View', onClick: () => Turbo.visit('#{ride_posts_path}')}});
    JS
    assert_selector '.toast-item[data-mounted="true"]', count: 3
    assert_surface_bounds
    assert_selector '.toast-item[data-expanded="false"]', count: 3
    find('.toast-item[data-front="true"] > span').hover
    assert_selector '.toast-item[data-expanded="true"]', count: 3
    # Wait for expansion to finish before measuring card separation.
    page.document.synchronize do
      expanded = page.evaluate_script <<~JS
        (() => {
          const cards = [...document.querySelectorAll('.toast-item > span')].map(e => e.getBoundingClientRect());
          return cards.slice(1).every((card, i) => card.top >= cards[i].bottom);
        })()
      JS
      raise Capybara::ExpectationNotMet unless expanded
    end
    assert_surface_bounds
    page.driver.resize(1440, 900)
    assert_surface_bounds
    page.execute_script('document.querySelector(".toast-item[data-front=\"true\"] button[aria-label=\"Dismiss notification\"]").focus()')
    page.driver.browser.keyboard.type(:Enter)
    assert_selector '.toast-item[data-removed="false"]', count: 2
    page.execute_script("window.toast('Maria requested a seat on your ride.', {type:'info', action:{label:'View', onClick:()=>Turbo.visit('#{ride_posts_path}')}})")
    assert_selector '.toast-item[data-front="true"] button', text: "View"
    find('.toast-item[data-front="true"] button', text: "View").click
    assert_current_path ride_posts_path
  end

  test "streamed seat request View opens the correct ride" do
    visit new_session_path
    fill_in "Email Address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_current_path root_path
    assert_selector "turbo-cable-stream-source[connected]", visible: :all
    page.execute_script("Stimulus.getControllerForElementAndIdentifier(document.getElementById('toast-container'), 'toast').autoDismissDurationValue = 60000")
    notification = notifications(:one)
    notification.deliver!
    assert_selector ".toast-item", text: notification.summary
    assert_surface_bounds
    find(".toast-item button", text: "View").click
    assert_current_path ride_post_path(ride_posts(:one))
    assert notification.reload.read_at.present?
  end

  private

  def assert_surface_bounds
    bounds = page.evaluate_script <<~JS
      (() => {
        const host = document.querySelector('#toast-container');
        return {cards: [...host.querySelectorAll('.toast-item[data-removed="false"] > span')].map(card => {
            const r = card.getBoundingClientRect();
            return {left:r.left, right:r.right};
          }), width:innerWidth};
      })()
    JS
    assert_not_empty bounds["cards"]
    bounds["cards"].each do |card|
      assert_operator card["left"], :>=, 0
      assert_operator card["right"], :<=, bounds["width"]
    end
  end
end
