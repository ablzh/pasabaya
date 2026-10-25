require "application_system_test_case"

class FormFeedbackSystemTest < ApplicationSystemTestCase
  test "ride corrections focus native and custom controls and clear only corrected fields" do
    sign_in(users(:one))
    visit new_ride_post_path
    fill_in "ride_post_notes", with: "Preserve my trip note"
    fill_in "ride_post_seats", with: ""
    click_button "Publish ride"
    assert_selector "[data-form-errors-summary][data-controller='form-errors']"
    assert_selector "[data-form-errors-summary]:focus"
    assert_field "ride_post_seats", with: ""
    assert_selector "#ride_post_origin_id-ts-control[aria-invalid='true']"
    find("[data-form-errors-summary] li[data-error-for='ride_post_origin_id'] a").click
    assert_equal "ride_post_origin_id-ts-search", page.evaluate_script("document.activeElement.id")
    assert_selector "#ride_post_origin_id-ts-search[aria-invalid='true'][aria-describedby~='ride_post_origin_id_error']"
    page.execute_script("document.querySelector('#ride_post_origin_id').tomselect.setValue(arguments[0])", locations(:one).id.to_s)
    assert_no_selector "#ride_post_origin_id_error"
    assert_selector "#ride_post_destination_id_error"
    find("[data-form-errors-summary] a[href='#ride_post_seats']").click
    assert_equal "ride_post_seats", page.evaluate_script("document.activeElement.id")
    click_button "Add one passenger seat"
    assert_field "ride_post_seats", with: "4"
    assert_no_selector "#ride_post_seats_error"
    assert_no_selector "a[href='#ride_post_seats']"
    assert_selector "#ride_post_departure_date_error"
    page.execute_script("document.querySelector('#ride_post_destination_id').tomselect.setValue(arguments[0])", locations(:two).id.to_s)
    fill_in "ride_post_departure_date", with: Date.tomorrow
    choose "Morning"
    assert_no_selector "#ride_post_departure_choice_error"
    assert_no_selector "fieldset[aria-invalid='true']"
    assert_field "ride_post_notes", with: "Preserve my trip note"
    click_button "Publish ride"
    assert_text "Ride post was successfully created."
    assert RidePost.exists?(user: users(:one), notes: "Preserve my trip note", seats: 4, status: :active)
  end

  test "error summaries fit phone and desktop with valid focus targets" do
    sign_in(users(:one))
    [ 320, 1440 ].each do |width|
      page.driver.resize(width, 900)
      visit new_ride_post_path
      fill_in "ride_post_notes", with: "Retained note"
      click_button "Publish ride"
      assert_selector "[data-form-errors-summary] a"
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "#{width}px must not overflow"
      assert page.evaluate_script(<<~JS)
        [...document.querySelectorAll('[data-form-errors-summary] a')].every(link => {
          const input = document.getElementById(link.hash.slice(1));
          return input && (input.tomselect || input.getClientRects().length > 0);
        })
      JS
    end
  end

  test "credential feedback stays in the failed form and clears passwords after rejection" do
    sign_in(users(:one))
    page.driver.resize(320, 900)
    visit settings_profile_path
    fill_in "password_change_user_password_challenge", with: "incorrect"
    fill_in "password_change_user_password", with: "new-fixture-password"
    fill_in "password_change_user_password_confirmation", with: "different-fixture-password"
    click_button "Update Password"
    assert_selector "#password_change_user_password_challenge_error"
    assert_selector "#password_change_user_password_confirmation_error"
    assert_selector "[data-form-errors-summary]", count: 1
    assert_no_selector "#email_change_user_password_challenge[aria-invalid]"
    assert_selector "#password_change_user_password_challenge[aria-invalid='true'][aria-describedby~='password_change_user_password_challenge_error']"
    %w[password_challenge password password_confirmation].each { |field| assert_field "password_change_user_#{field}", with: "" }
    find("[data-form-errors-summary] a[href='#password_change_user_password_challenge']").click
    assert_equal "password_change_user_password_challenge", page.evaluate_script("document.activeElement.id")
    fill_in "password_change_user_password_challenge", with: "still incorrect"
    assert_selector "#password_change_user_password_challenge_error"
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    fill_in "password_change_user_password_challenge", with: "password"
    fill_in "password_change_user_password", with: "new-fixture-password"
    fill_in "password_change_user_password_confirmation", with: "new-fixture-password"
    click_button "Update Password"
    assert_text "Password changed successfully."
    assert users(:one).reload.authenticate("new-fixture-password")
  end

  test "background morph keeps edited profile controls while reset and submission accept server state" do
    user = users(:one)
    sign_in(user)
    visit settings_profile_path
    watch_morphs
    fill_in "First Name", with: "Unsent first name"
    select "Female", from: "Gender (Self-Declared)"
    find("#user_first_name").execute_script("this.focus(); this.setSelectionRange(2, 5)")
    user.update!(last_name: "Refreshed surname")

    refresh_page

    assert_field "user_first_name", with: "Unsent first name"
    assert_selector "#user_first_name:focus"
    assert_equal [ 2, 5 ], find("#user_first_name").evaluate_script("[this.selectionStart, this.selectionEnd]")
    assert_field "user_gender", with: "female"
    assert_field "user_last_name", with: "Refreshed surname"

    find("#profile_form").execute_script("this.reset()")
    user.update!(first_name: "After reset")
    refresh_page
    assert_field "user_first_name", with: "After reset"

    fill_in "First Name", with: "Submitted first name"
    click_button "Save Profile Changes"
    assert_text "Profile updated successfully."
    assert_equal "Submitted first name", user.reload.first_name
    user.update!(first_name: "After submission")
    refresh_page
    assert_field "user_first_name", with: "After submission"
  end

  test "background morph preserves unsent ride text and choices alongside refreshed capacity" do
    ride = ride_posts(:two)
    sign_in(users(:two))
    visit edit_ride_post_path(ride)
    watch_morphs
    choose "Morning"
    check "ride_post_ladies_only"
    fill_in "Details & Preferences", with: "Unsent trip note"
    ride.update!(seats: 4)

    refresh_page

    assert_field "ride_post_notes", with: "Unsent trip note"
    assert_selector "#ride_post_notes:focus"
    assert_checked_field "ride_post_departure_choice_morning"
    assert_checked_field "ride_post_ladies_only"
    assert_no_field "Departure Time"
    assert_field "ride_post_seats", with: "4"

    click_button "Save Changes"
    assert_text "Ride post was successfully updated."
    assert_equal "Unsent trip note", ride.reload.notes
    assert ride.morning?
    assert ride.ladies_only?
  end

  test "background morph keeps regular mode weekday shortcuts and optional end date" do
    sign_in(users(:one))
    visit new_ride_post_path
    watch_morphs
    fill_in "ride_post_seats", with: ""
    choose "Regular"
    click_button "Weekdays"
    check "Set an end date", allow_label_click: true
    fill_in "Repeat until", with: 1.month.from_now.to_date

    refresh_page

    assert_checked_field "ride_type_regular"
    (1..5).each { |day| assert_checked_field "ride_post_weekday_#{day}" }
    assert_unchecked_field "ride_post_weekday_0"
    assert_unchecked_field "ride_post_weekday_6"
    assert_checked_field "ride_post_end_date_enabled"
    assert_field "ride_post_end_date", with: 1.month.from_now.to_date.to_s, disabled: false
    assert_field "ride_post_seats", with: ""
    assert_no_field "ride_post_departure_date"

    click_button "Every day"
    refresh_page
    (0..6).each { |day| assert_checked_field "ride_post_weekday_#{day}" }
  end

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

  test "settings password labels focus their own inputs" do
    sign_in(users(:one))
    visit settings_profile_path
    %w[email_change password_change].each do |namespace|
      id = "#{namespace}_user_password_challenge"
      find("label[for='#{id}']").click
      assert_equal id, page.evaluate_script("document.activeElement.id")
    end
  end

  test "mobile schedule text and settings actions fit with a scrollbar gutter" do
    sign_in(users(:one))
    [ new_ride_post_path, edit_ride_post_path(ride_posts(:one)), settings_profile_path ].each do |path|
      resize_and_visit(320, path)
      page.execute_script("const style = document.createElement('style'); style.textContent = 'html {overflow-y:scroll;scrollbar-gutter:stable} ::-webkit-scrollbar {width:15px}'; document.head.append(style)")
      assert_document_contained
      if path == settings_profile_path
        assert_contained("form button[type='submit']", "form", parent: true)
      else
        assert_contained("[data-controller='departure-choice'] label span", "[data-controller='departure-choice'] label", parent: true)
        [ "Add one passenger seat", "Remove one passenger seat" ].each do |label|
          bounds = find("button[aria-label='#{label}']").evaluate_script("this.getBoundingClientRect().toJSON()")
          %w[width height].each { |dimension| assert_operator bounds[dimension], :>=, 44 }
        end
      end
    end
  end

  test "avatar preview keeps the last valid image when a replacement is invalid" do
    sign_in(users(:one))
    resize_and_visit(390, settings_profile_path)
    image = Tempfile.new([ "preview", ".png" ])
    image.binmode
    image.write(Vips::Image.black(200, 20).pngsave_buffer)
    image.flush
    attach_file "Upload Avatar", image.path
    assert_selector "img[data-avatar-preview-target='preview']"
    preview_src = find("img[data-avatar-preview-target='preview']")[:src]

    invalid = nil
    [ ".txt", ".png" ].each do |extension|
      invalid = Tempfile.new([ "invalid-preview", extension ])
      invalid.write("Not an image")
      invalid.flush
      attach_file "Upload Avatar", invalid.path
      page.document.synchronize do
        raise Capybara::ExpectationNotMet if find("input[type='file']").evaluate_script("this.validity.valid")
      end
      assert_equal preview_src, find("img[data-avatar-preview-target='preview']")[:src]
      assert find("img[data-avatar-preview-target='preview']").evaluate_script("this.complete && this.naturalWidth > 0")
      invalid.close!
    end
  ensure
    image&.close!
    invalid&.close! unless invalid&.closed?
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

  def watch_morphs
    page.execute_script("window.observedMorphs = 0; document.addEventListener('turbo:morph', () => window.observedMorphs++)")
  end

  def refresh_page
    previous = page.evaluate_script("window.observedMorphs")
    page.execute_script("Turbo.renderStreamMessage('<turbo-stream action=\"refresh\"></turbo-stream>')")
    page.document.synchronize do
      raise Capybara::ExpectationNotMet unless page.evaluate_script("window.observedMorphs") > previous
    end
  end
end
