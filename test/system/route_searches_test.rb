require "application_system_test_case"

class RouteSearchesTest < ApplicationSystemTestCase
  test "search controls and long route labels remain usable on phone and desktop" do
    # Exercise wrapping/truncation with realistic long labels using only isolated fixtures.
    locations(:one).update!(name: "Manila — Metro Manila meeting point")
    [ [ 320, "light" ], [ 1440, "dark" ] ].product([ :home, :board ]).each do |(width, theme), surface|
      page.driver.resize(width, width < 768 ? 844 : 1024)
      visit(surface == :home ? root_path : ride_posts_path)
      set_theme(theme)
      assert_selector "#origin_id-ts-control"
      choose_city("origin_id", locations(:one).name)
      choose_city("destination_id", "Makati")
      measurements = page.evaluate_script <<~JS
        (() => {
          const panel = document.querySelector('[data-search-panel]');
          const rect = e => e.getBoundingClientRect().toJSON();
          const from = document.querySelector('#origin_id').tomselect.wrapper;
          const to = document.querySelector('#destination_id').tomselect.wrapper;
          return {panel: rect(panel), from: rect(from), to: rect(to), button: rect(panel.querySelector('button[type=submit]')),
            swap: rect(panel.querySelector('button[type=button]')),
            date: rect(panel.querySelector('input[type=date]')),
            overflow: document.documentElement.scrollWidth > innerWidth};
        })()
      JS
      assert_operator measurements["swap"]["width"], :>=, 44
      assert_operator measurements["swap"]["height"], :>=, 44
      %w[from to swap button date].each do |control|
        assert_operator measurements[control]["left"], :>=, measurements["panel"]["left"]
        assert_operator measurements[control]["right"], :<=, measurements["panel"]["right"]
      end
      assert_not measurements["overflow"], "#{surface} #{width}px #{theme} overflow"
      find("#destination_id-ts-control").click
      assert_selector ".ts-dropdown", visible: true
      assert page.evaluate_script("(() => { const option = document.querySelector('#destination_id + .ts-wrapper .ts-dropdown .option'); const r = option.getBoundingClientRect(); return document.elementFromPoint(r.left + 5, r.top + 5).closest('.option') === option })()"), "Swap must not cover dropdown options"
      find("#destination_id-ts-control").send_keys(:escape)
    end
  end

  test "search submits swapped route and date then resets filters" do
    visit ride_posts_path
    choose_city("origin_id", "Makati")
    choose_city("destination_id", "Manila")
    click_button "Swap Origin and Destination"
    fill_in "Date", with: Date.tomorrow.to_s
    click_button "Search Rides"
    assert_selector "#ride_post_#{ride_posts(:one).id}"
    assert_equal locations(:one).id.to_s, find("#origin_id", visible: false).value
    assert_equal locations(:two).id.to_s, find("#destination_id", visible: false).value
    assert_equal Date.tomorrow.to_s, find("#departure_date").value
    click_link "Clear filters"
    assert_current_path ride_posts_path
    page.document.synchronize do
      raise Capybara::ExpectationNotMet unless find("#origin_id", visible: false).value == ""
    end
    assert_equal "", find("#origin_id", visible: false).value
    assert_equal "", find("#destination_id", visible: false).value
    assert_equal "", find("#departure_date").value
  end

  test "partial route alert pickers are labeled and create subscriptions in both directions" do
    passenger = users(:two)
    empty_city = Location.create!(name: "Empty Alert City", location_type: :city)
    expected_routes = []
    sign_in(passenger)

    [ [ :origin, "Destination", "destination" ], [ :destination, "Origin", "origin" ] ].each do |known_endpoint, label, missing_endpoint|
      visit ride_posts_path("#{known_endpoint}_id" => empty_city.id)
      control_id = "subscription_#{missing_endpoint}_id"
      assert_selector "##{control_id}-ts-control[aria-labelledby]"
      find("label", text: label, exact_text: true).click
      assert page.evaluate_script("document.querySelector(arguments[0]).tomselect.wrapper.contains(document.activeElement)", "##{control_id}")

      within "#route_subscription_partial_form" do
        assert_selector "input[type='submit'][id]"
        find(".ts-dropdown .option", text: locations(:one).name, exact_text: true).click
        click_button "Notify me when a driver posts this route"
      end
      assert_text "You will be notified when a matching ride is posted."
      expected_route = { "#{known_endpoint}_id" => empty_city.id, "#{missing_endpoint}_id" => locations(:one).id }
      expected_routes << expected_route.values_at("origin_id", "destination_id")
    end
    assert_equal expected_routes.sort, passenger.route_subscriptions.active.pluck(:origin_id, :destination_id).sort
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
    page.driver.browser.keyboard.type(:Escape)
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

  def choose_city(id, name)
    find("##{id}-ts-control").click
    find(".ts-dropdown .option", text: name, exact_text: true).click
  end
end
