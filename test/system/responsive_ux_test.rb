require "application_system_test_case"

class ResponsiveUxTest < ApplicationSystemTestCase
  test "route pickers preserve IDs and reopen through repeated create and edit failures" do
    sign_in(users(:one))
    page.driver.resize(390, 844)
    visit new_ride_post_path
    choose_city("ride_post_origin_id", "Manila")
    choose_city("ride_post_destination_id", "Makati")
    fill_in "Available passenger seats", with: 1
    fill_in "Departure Date", with: 3.days.from_now.to_date
    choose "Exact Time"
    fill_in "Departure Time", with: "09:00"
    select "Community / Closed Hub Only", from: "Visibility"
    page.execute_script("window.formRenders = 0; document.addEventListener('turbo:render', () => window.formRenders++)")
    2.times do
      submit_and_wait("Publish ride")
      assert_selector "#ride_post_community_id_error"
      assert_routes
      reopen_routes
    end
    select "Public (Everyone)", from: "Visibility"
    click_button "Publish ride"
    assert_text "Ride post was successfully created."
    ride = RidePost.order(:created_at).last
    assert_equal locations(:one).id, ride.origin_id
    assert_equal locations(:two).id, ride.destination_id
    assert_equal 1, ride.seats

    click_link "Edit Post"
    assert_selector "#ride_post_origin_id-ts-control"
    select "Community / Closed Hub Only", from: "Visibility"
    2.times do
      submit_and_wait("Save Changes")
      assert_routes
      reopen_routes
    end
    select "Public (Everyone)", from: "Visibility"
    click_button "Save Changes"
    assert_text "Ride post was successfully updated."
    assert_equal [ locations(:one).id, locations(:two).id ], [ ride.reload.origin_id, ride.destination_id ]
  end

  test "search controls and long route labels remain usable on phone and desktop" do
    # Exercise wrapping/truncation with realistic long labels using only isolated fixtures.
    locations(:one).update!(name: "Manila — Metro Manila meeting point")
    [ [ 320, "light" ], [ 1440, "dark" ] ].product([ :home, :board ]).each do |(width, theme), surface|
      page.driver.resize(width, width < 768 ? 844 : 1024)
      visit(surface == :home ? root_path : ride_posts_path)
      theme!(theme)
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

  test "settings password labels focus their own inputs" do
    sign_in(users(:one))
    visit settings_profile_path
    %w[email_change password_change].each do |namespace|
      id = "#{namespace}_user_password_challenge"
      find("label[for='#{id}']").click
      assert_equal id, page.evaluate_script("document.activeElement.id")
    end
  end

  private

  def choose_city(id, name)
    find("##{id}-ts-control").click
    find(".ts-dropdown .option", text: name, exact_text: true).click
  end

  def assert_routes
    assert_equal locations(:one).id.to_s, find("#ride_post_origin_id", visible: false).value
    assert_equal locations(:two).id.to_s, find("#ride_post_destination_id", visible: false).value
  end

  def reopen_routes
    %w[origin destination].each do |route|
      find("#ride_post_#{route}_id-ts-control").click
      assert_selector ".ts-dropdown .option", text: route == "origin" ? "Manila" : "Makati"
      find("#ride_post_#{route}_id-ts-control").send_keys(:escape)
    end
  end

  def submit_and_wait(label)
    renders = page.evaluate_script("window.formRenders")
    click_button label
    page.document.synchronize do
      raise Capybara::ExpectationNotMet unless page.evaluate_script("window.formRenders") > renders
    end
    assert_selector "[data-form-errors-summary]"
  end

  def theme!(theme)
    page.execute_script("localStorage.setItem('theme', '#{theme}'); document.documentElement.classList.toggle('dark', '#{theme}' === 'dark'); document.documentElement.style.colorScheme = '#{theme}'")
  end
end
