require "application_system_test_case"

class ResponsiveUxTest < ApplicationSystemTestCase
  WIDTHS = [ 320, 360, 390, 768, 1440 ].freeze

  test "route pickers preserve IDs and reopen through repeated create and edit failures" do
    sign_in
    page.driver.resize(390, 844)
    visit new_ride_post_path
    choose_city("ride_post_origin_id", "Manila")
    choose_city("ride_post_destination_id", "Makati")
    fill_in "Available passenger seats", with: 1
    fill_in "Departure Time", with: 3.days.from_now.strftime("%Y-%m-%dT09:00")
    fill_in "Expected Arrival Time", with: 3.days.from_now.strftime("%Y-%m-%dT12:00")
    select "Community / Closed Hub Only", from: "Visibility"
    page.execute_script("window.formRenders = 0; document.addEventListener('turbo:render', () => window.formRenders++)")
    2.times do
      submit_and_wait("Publish ride")
      assert_text "Community can't be blank"
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

  test "search routes stay stacked aligned and contained on home and board in both themes" do
    # Exercise wrapping/truncation with realistic long labels using only isolated fixtures.
    locations(:one).update!(name: "Manila — Metro Manila meeting point")
    WIDTHS.product(%w[light dark], [ :home, :board ]).each do |width, theme, surface|
      page.driver.resize(width, width < 768 ? 844 : 1024)
      visit(surface == :home ? root_path : ride_posts_path)
      theme!(theme)
      assert_selector "#origin_id-ts-control"
      choose_city("origin_id", locations(:one).name)
      choose_city("destination_id", "Makati")
      find('button[aria-label="Swap Origin and Destination"]').click
      assert_equal locations(:two).id.to_s, find("#origin_id", visible: false).value
      assert_equal locations(:one).id.to_s, find("#destination_id", visible: false).value
      assert_current_path(surface == :home ? root_path : ride_posts_path)
      measurements = page.evaluate_script <<~JS
        (() => {
          const panel = document.querySelector('[data-search-panel]');
          const rect = e => e.getBoundingClientRect().toJSON();
          const from = document.querySelector('#origin_id').tomselect.wrapper;
          const to = document.querySelector('#destination_id').tomselect.wrapper;
          const button = panel.querySelector('button[type=submit]');
          return {panel: rect(panel), from: rect(from), to: rect(to), button: rect(button),
            swap: rect(panel.querySelector('button[type=button]')),
            date: rect(panel.querySelector('input[type=date]')),
            fromLabel: rect(panel.querySelector('label[for=origin_id-ts-control]')),
            toLabel: rect(panel.querySelector('label[for=destination_id-ts-control]')),
            decoration: {inset: getComputedStyle(button, '::before').inset},
            overflow: document.documentElement.scrollWidth > innerWidth};
        })()
      JS
      assert_operator measurements["from"]["bottom"], :<, measurements["to"]["top"]
      %w[left right].each { |edge| assert_in_delta measurements["from"][edge], measurements["to"][edge], 1 }
      assert_in_delta measurements["fromLabel"]["left"], measurements["from"]["left"], 1
      assert_in_delta measurements["toLabel"]["left"], measurements["to"]["left"], 1
      assert_operator measurements["swap"]["left"], :>, measurements["from"]["right"]
      assert_operator measurements["swap"]["top"], :>=, measurements["fromLabel"]["top"]
      assert_operator measurements["swap"]["bottom"], :<=, measurements["to"]["bottom"]
      %w[button date].each do |control|
        assert_operator measurements[control]["left"] - measurements["panel"]["left"], :>=, 16
        assert_operator measurements["panel"]["right"] - measurements[control]["right"], :>=, 16
        assert_operator measurements["panel"]["bottom"] - measurements[control]["bottom"], :>=, 16
      end
      assert_equal "0px", measurements["decoration"]["inset"]
      assert_not measurements["overflow"], "#{surface} #{width}px #{theme} overflow"
      find("#destination_id-ts-control").click
      assert_selector ".ts-dropdown", visible: true
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
    assert_text "Where are you heading?"
    page.document.synchronize do
      raise Capybara::ExpectationNotMet unless find("#origin_id", visible: false).value == ""
    end
    assert_equal "", find("#origin_id", visible: false).value
    assert_equal "", find("#destination_id", visible: false).value
    assert_equal "", find("#departure_date").value
  end

  test "settings labels focus their own inputs and driver form recovers after errors" do
    sign_in
    visit settings_profile_path
    %w[email_change password_change].each do |namespace|
      id = "#{namespace}_user_password_challenge"
      find("label[for='#{id}']").click
      assert_equal id, page.evaluate_script("document.activeElement.id")
      assert_equal "Current password *", find("##{id}")["aria-label"] || page.evaluate_script("document.querySelector('label[for=#{id}]').textContent.trim().replace(/\\s+/g, ' ')")
    end
    visit new_ride_post_path
    assert_selector "label", text: "Available passenger seats", exact_text: true
    assert_text "Offer seats as a driver"
    choose_city("ride_post_origin_id", "Manila")
    choose_city("ride_post_destination_id", "Makati")
    fill_in "Available passenger seats", with: 1
    select "Community / Closed Hub Only", from: "Visibility"
    click_button "Publish ride"
    assert_selector "#error_explanation"
    assert_selector "label", text: "Departure Time (required to publish a ride offer)", exact_text: true
    assert_routes
    select "Public (Everyone)", from: "Visibility"
    click_button "Save draft"
    assert_text "Ride saved as a private draft."
    assert_text "Unpublished — edit to publish"
    assert_no_link "Review Trip / Report No-Show"
  end

  private

  def sign_in
    visit new_session_path
    fill_in "Email Address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_current_path root_path
  end

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
    assert_selector "#error_explanation"
  end

  def theme!(theme)
    page.execute_script("localStorage.setItem('theme', '#{theme}'); document.documentElement.classList.toggle('dark', '#{theme}' === 'dark'); document.documentElement.style.colorScheme = '#{theme}'")
  end
end
