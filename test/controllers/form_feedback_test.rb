require "test_helper"

class FormFeedbackTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
    @origin = locations(:one)
    @destination = locations(:two)
  end

  test "password failure belongs to password form and passwords are never returned" do
    patch settings_password_url, params: { user: { password_challenge: "wrong-secret", password: "new-secret", password_confirmation: "different-secret" } }
    assert_response :unprocessable_content
    assert_select "[data-form-errors-summary] h2", text: /\S/
    assert_select "#password_change_user_password_challenge[aria-invalid='true'][aria-describedby~='password_change_user_password_challenge_error']"
    assert_select "#password_change_user_password_challenge_error", text: /\S/
    assert_select "#password_change_user_password_confirmation_error", text: /\S/
    assert_select "#email_change_user_password_challenge[aria-invalid]", count: 0
    assert_select "input[type=password][value]", count: 0
  end

  test "empty publication has only visible actionable corrections and keeps seats empty" do
    post ride_posts_url, params: { intent: "publish", ride_post: { origin_id: "", destination_id: "", seats: "", notes: "Keep this note" } }
    assert_response :unprocessable_content
    assert_select "[data-form-errors-summary] h2", text: /\S/
    assert_select "#ride_post_origin_id_error", text: /\S/
    assert_select "#ride_post_destination_id_error", text: /\S/
    assert_select "#ride_post_departure_choice_error", text: /\S/
    assert_select "#ride_post_seats_error", text: /\S/
    assert_select "[data-form-errors-summary] li[data-error-for='ride_post_exact_departure_time']", count: 0
    assert_select "[data-form-errors-summary] li[data-error-for='ride_post_seats']", count: 1
    assert_select "#ride_post_seats[value='']"
    assert_select "textarea#ride_post_notes", text: "Keep this note"
    assert_select "a[href='#ride_post_origin_id']", text: /\S/
  end

  test "email errors retain the address and do not highlight the password-change form" do
    patch settings_email_url, params: { user: { password_challenge: "wrong-secret", unconfirmed_email: "not-an-email" } }
    assert_response :unprocessable_content
    assert_select "#email_change_user_unconfirmed_email[value='not-an-email'][aria-invalid='true']"
    assert_select "#email_change_user_unconfirmed_email_error", text: /\S/
    assert_select "#email_change_user_password_challenge_error", text: /\S/
    assert_select "#password_change_user_password_challenge[aria-invalid]", count: 0
    assert_select "[data-form-errors-summary]", count: 1
    assert_select "input[type=password][value]", count: 0
  end

  test "empty credential changes reject rather than report success" do
    digest = users(:one).password_digest
    patch settings_password_url, params: { user: { password_challenge: "password", password: "", password_confirmation: "" } }
    assert_response :unprocessable_content
    assert_select "#password_change_user_password_error", text: /\S/
    assert_equal digest, users(:one).reload.password_digest
    patch settings_email_url, params: { user: { password_challenge: "password", unconfirmed_email: "" } }
    assert_response :unprocessable_content
    assert_select "#email_change_user_unconfirmed_email_error", text: /\S/
    assert_nil users(:one).reload.unconfirmed_email
  end

  test "ride exact-time requirement only targets the visible time field" do
    route = { origin_id: @origin.id, destination_id: @destination.id,
      departure_date: Date.tomorrow.to_s, seats: 2, departure_choice: "exact_time", exact_departure_time: "" }
    post ride_posts_url, params: { intent: "publish", ride_post: route }
    assert_response :unprocessable_content
    assert_select "#ride_post_exact_departure_time_error", text: /\S/
    assert_select "a[href='#ride_post_exact_departure_time']", text: /\S/
    assert_select "#ride_post_seats[value='2']"
    assert_select "[data-form-errors-summary] li", count: 1
    post ride_posts_url, params: { intent: "publish", ride_post: route.merge(departure_choice: "morning") }
    assert_response :see_other
  end

  test "ride feedback explains route notes and seat rules and retains inputs" do
    route = { origin_id: @origin.id, destination_id: @origin.id,
      departure_date: Date.tomorrow.to_s, departure_choice: "exact_time", exact_departure_time: "12:00",
      seats: "0", notes: "x" * 301 }
    post ride_posts_url, params: { intent: "publish", ride_post: route }
    assert_response :unprocessable_content
    assert_select "#ride_post_destination_id_error", text: /\S/
    assert_select "#ride_post_notes_error", text: /\S/
    assert_select "#ride_post_seats_error", text: /\S/
    assert_select "#ride_post_notes_hint", text: /\S/
    assert_select "textarea#ride_post_notes[aria-describedby~='ride_post_notes_hint'][aria-describedby~='ride_post_notes_error']", text: route[:notes]
    assert_select "#ride_post_seats[value='0']"
    assert_select "#ride_post_origin_id option[value='#{@origin.id}'][selected]"
  end

  test "incomplete draft still saves" do
    post ride_posts_url, params: { intent: "draft", ride_post: { notes: "Still planning", seats: "" } }
    assert_response :see_other
    ride = RidePost.order(:id).last
    assert ride.draft?
    assert_nil ride.seats
  end

  test "password reset feedback remains in the form with no password values or duplicate flash" do
    delete session_url
    token = users(:one).password_reset_token
    put password_url(token), params: { password: "new-secret", password_confirmation: "different-secret" }
    assert_response :unprocessable_content
    assert_select "#password_confirmation_error", text: /\S/
    assert_select "input[type=password][value]", count: 0
    assert_select "[data-persistent-feedback]", count: 0
    assert_select "[data-form-errors-summary]", count: 1
  end

  test "redirected booking errors persist without a duplicate transient error" do
    post ride_post_bookings_url(ride_posts(:one))
    assert_response :see_other
    follow_redirect!
    assert_select "[data-persistent-feedback]", count: 1
    assert_select "[data-persistent-feedback] li", text: /\S/
    assert_select "[data-flash-toasts-target][data-type=error]", count: 0
  end
end
