require "application_system_test_case"

class ToastInteractionTest < ApplicationSystemTestCase
  test "notifications leave account navigation usable on phone and desktop" do
    sign_in(users(:one))
    [ 320, 1400 ].each do |width|
      page.driver.resize(width, 844)
      visit root_path
      page.execute_script <<~JS
        Stimulus.getControllerForElementAndIdentifier(document.getElementById('toast-container'), 'toast').autoDismissDurationValue = 60000;
        window.toast('Regular schedule saved', {type: 'success'});
      JS
      assert_selector '.toast-item[data-mounted="true"]', text: "Regular schedule saved"

      find("button[aria-label='Account menu']").click
      within("#profile-content") { click_link "Profile" }
      assert_current_path user_path(users(:one))
    end
  end

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
    sign_in(users(:one))
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

  test "keyboard navigation reaches every toast action and activates an older notification" do
    page.driver.resize(320, 844)
    visit root_path
    page.execute_script <<~JS
      Stimulus.getControllerForElementAndIdentifier(document.getElementById('toast-container'), 'toast').autoDismissDurationValue = 60000;
      window.toastActions = [];
      for (let i = 1; i <= 3; i++) {
        window.toast(`Request ${i}`, {action: {label: `Open request ${i}`, onClick: () => window.toastActions.push(i)}});
      }
      document.querySelector('nav a[href="#{sign_up_path}"]').focus();
    JS
    assert_selector '.toast-item[data-mounted="true"]', count: 3
    assert_button "Open request 3"

    page.driver.browser.keyboard.type(:Tab)
    assert_selector "button:focus", text: "Open request 3"
    assert_button "Open request 2"
    assert_button "Open request 1"

    [ 2, 1 ].each do |number|
      page.driver.browser.keyboard.type(:Tab, :Tab)
      assert_selector "button:focus", text: "Open request #{number}"
    end
    page.driver.browser.keyboard.type(:Enter)
    assert_equal [ 1 ], page.evaluate_script("window.toastActions")
    assert_selector '.toast-item[data-removed="false"]', count: 2
    assert_selector ".toast-item button:focus"
  end

  test "a focused toast survives timeout incoming notifications and a Turbo morph" do
    visit root_path
    page.execute_script <<~JS
      Stimulus.getControllerForElementAndIdentifier(document.getElementById('toast-container'), 'toast').autoDismissDurationValue = 1200;
      window.toast('Focused request', {action: {label: 'Open focused request', onClick: () => {}}});
      document.querySelector('nav a[href="#{sign_up_path}"]').focus();
      window.observedMorphs = 0;
      document.addEventListener('turbo:morph', () => window.observedMorphs++);
    JS
    assert_selector '.toast-item[data-mounted="true"]'
    assert_button "Open focused request"
    page.driver.browser.keyboard.type(:Tab)
    assert_selector "button:focus", text: "Open focused request"
    action_id = page.evaluate_script("document.activeElement.id")
    assert action_id.present?, "Toast actions need stable IDs"
    find("footer").hover

    page.execute_script <<~JS
      for (let i = 1; i <= 3; i++) window.toast(`Later request ${i}`);
      Turbo.renderStreamMessage('<turbo-stream action="refresh"></turbo-stream>');
    JS
    page.document.synchronize do
      raise Capybara::ExpectationNotMet unless page.evaluate_script("window.observedMorphs") > 0
    end
    page.evaluate_async_script("setTimeout(arguments[0], 1400)")

    assert_selector "##{action_id}:focus", text: "Open focused request"
    assert_selector '.toast-item[data-removed="false"]', count: 3
    assert page.evaluate_script("(() => { const ids = [...document.querySelectorAll('#toast-container [id]')].map(el => el.id); return ids.length === new Set(ids).size; })()")

    page.execute_script("document.querySelector('nav a[href=\"#{sign_up_path}\"]').focus()")
    assert_no_selector '.toast-item[data-removed="false"]', wait: 4
  end

  test "pointer interaction pauses dismissal until the pointer leaves the toast stack" do
    visit root_path
    page.execute_script <<~JS
      Stimulus.getControllerForElementAndIdentifier(document.getElementById('toast-container'), 'toast').autoDismissDurationValue = 1000;
      window.toast('Review this notification');
    JS
    assert_selector '.toast-item[data-mounted="true"]'
    find(".toast-item > span").hover
    page.evaluate_async_script("setTimeout(arguments[0], 1200)")
    assert_selector '.toast-item[data-removed="false"]', text: "Review this notification"

    find("footer").hover
    assert_no_selector '.toast-item[data-removed="false"]', wait: 4
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
