require "application_system_test_case"

class ToastInteractionTest < ApplicationSystemTestCase
  test "toast surface fits short multiline action stacks hover dismissal and Turbo navigation in both themes" do
    [ 320, 360, 390, 768, 1440 ].product(%w[light dark]).each do |width, theme|
      page.driver.resize(width, width < 768 ? 844 : 900)
      visit root_path
      page.execute_script <<~JS
        localStorage.setItem('theme', '#{theme}');
        document.documentElement.classList.toggle('dark', '#{theme}' === 'dark');
        document.documentElement.style.colorScheme = '#{theme}';
        window.__toastPrimaryController.autoDismissDurationValue = 60000;
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
            return cards.slice(1).every((card, i) => card.top >= cards[i].bottom + 10);
          })()
        JS
        raise Capybara::ExpectationNotMet unless expanded
      end
      assert_surface_bounds
      page.execute_script('document.querySelector(".toast-item[data-front=\"true\"] button[aria-label=\"Dismiss notification\"]").focus()')
      page.driver.browser.keyboard.type(:Enter)
      assert_selector '.toast-item[data-removed="false"]', count: 2
      page.execute_script("window.toast('Maria requested a seat on your ride.', {type:'info', action:{label:'View', onClick:()=>Turbo.visit('#{ride_posts_path}')}})")
      assert_selector '.toast-item[data-front="true"] button', text: "View"
      find('.toast-item[data-front="true"] button', text: "View").click
      assert_current_path ride_posts_path
      assert_text "Where are you heading?"
      assert_no_selector '.toast-item[data-removed="false"]'
      page.execute_script("window.toast('Navigation still works.')")
      assert_selector '.toast-item[data-mounted="true"]', text: "Navigation still works."
      assert_surface_bounds
      find('button[aria-label="Dismiss notification"]').click
      assert_no_selector '.toast-item[data-removed="false"]'
    end
  end

  test "streamed seat request View opens the correct ride" do
    actor = users(:two)
    visit new_session_path
    fill_in "Email Address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_current_path root_path
    assert_selector "turbo-cable-stream-source[connected]", visible: :all
    page.execute_script("window.__toastPrimaryController.autoDismissDurationValue = 60000")
    notification = notifications(:one)
    notification.deliver!
    assert_selector ".toast-item", text: "#{actor.first_name} requested a seat on your ride."
    assert_surface_bounds
    find(".toast-item button", text: "View").click
    assert_current_path ride_post_path(ride_posts(:one))
    assert notification.reload.read_at.present?
  end

  private

  def assert_surface_bounds
    styles = page.evaluate_script <<~JS
      (() => {
        const host = document.querySelector('#toast-container');
        const style = getComputedStyle(host);
        return {background: style.backgroundColor, border: style.borderWidth, shadow: style.boxShadow,
          cards: [...host.querySelectorAll('.toast-item[data-removed="false"] > span')].map(card => {
            const r = card.getBoundingClientRect(); const s = getComputedStyle(card);
            return {left:r.left, right:r.right, radius:s.borderRadius, border:s.borderWidth, background:s.backgroundColor, shadow:s.boxShadow};
          }), width:innerWidth};
      })()
    JS
    assert_equal "rgba(0, 0, 0, 0)", styles["background"]
    assert_equal "0px", styles["border"]
    assert_equal "none", styles["shadow"]
    styles["cards"].each do |card|
      assert_operator card["left"], :>=, 15
      assert_operator styles["width"] - card["right"], :>=, 15
      assert_not_equal "0px", card["radius"]
      assert_equal "1px", card["border"]
      assert_not_equal "rgba(0, 0, 0, 0)", card["background"]
      assert_not_equal "none", card["shadow"]
    end
  end
end
