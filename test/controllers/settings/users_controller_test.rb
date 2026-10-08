# frozen_string_literal: true

require "test_helper"

class Settings::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: "settings_user@example.com",
      password: "password",
      first_name: "Test",
      last_name: "Settings",
      facebook_profile_url: "https://facebook.com/testsettings"
    )
    sign_in_as(@user)
  end

  test "anonymizes account with valid password when unconstrained" do
    assert_no_difference("User.count") do
      delete settings_user_url, params: { password_challenge: "password" }
    end

    assert_redirected_to root_url
    assert_equal "Your account has been deleted.", flash[:notice]
    assert_empty cookies[:session_id]

    @user.reload
    assert @user.deleted?
    assert_equal "Deleted", @user.first_name
    assert_equal "User", @user.last_name
    assert_nil @user.facebook_profile_url
  end

  test "anonymizes account with valid password even when user has trip reviews" do
    driver = users(:one)
    ride = ride_posts(:one)
    Booking.create!(ride_post: ride, passenger: @user, status: :accepted)
    ride.update_columns(departure_time: 2.hours.ago, expected_arrival_at: 1.hour.ago)

    review = TripReview.create!(
      ride_post: ride,
      reporter: @user,
      reported_user: driver,
      outcome: :completed,
      notes: "Trip went smoothly."
    )

    assert_no_difference("User.count") do
      delete settings_user_url, params: { password_challenge: "password" }
    end

    assert_redirected_to root_url
    assert_equal "Your account has been deleted.", flash[:notice]
    assert_empty cookies[:session_id]

    @user.reload
    assert @user.deleted?
    assert TripReview.exists?(review.id)
    assert_nil review.reload.notes
  end

  test "fails with incorrect password" do
    assert_no_difference("User.count") do
      delete settings_user_url, params: { password_challenge: "wrong_password" }
    end

    assert_response :unprocessable_content
    assert_select "#password_challenge_error", text: "Your current password is incorrect."
    assert_not @user.reload.deleted?
  end

  test "anonymizes account when driver has departed ride with historical participation" do
    ride = ride_posts(:one)
    booking = bookings(:one)
    ride.update_columns(user_id: @user.id, departure_time: 2.hours.ago, expected_arrival_at: 1.hour.ago)
    booking.update_columns(status: Booking.statuses[:accepted], accepted_at: 3.hours.ago)

    assert_no_difference "User.count" do
      delete settings_user_url, params: { password_challenge: "password" }
    end

    assert_redirected_to root_url
    assert_equal "Your account has been deleted.", flash[:notice]
    assert_empty cookies[:session_id]

    assert @user.reload.deleted?
    assert RidePost.exists?(ride.id)
  end

  test "anonymizes account when passenger has historical participation on departed ride" do
    ride = ride_posts(:one)
    booking = bookings(:one)
    booking.update_columns(passenger_id: @user.id, status: Booking.statuses[:accepted], accepted_at: 3.hours.ago)
    ride.update_columns(departure_time: 2.hours.ago, expected_arrival_at: 1.hour.ago)

    assert_no_difference "User.count" do
      delete settings_user_url, params: { password_challenge: "password" }
    end

    assert_redirected_to root_url
    assert_equal "Your account has been deleted.", flash[:notice]
    assert_empty cookies[:session_id]

    assert @user.reload.deleted?
    assert Booking.exists?(booking.id)
  end

  test "subsequent requests using session of deleted user are rejected and terminate session" do
    assert_not_nil cookies[:session_id]

    Users::AnonymizeService.call(@user)

    get settings_profile_url

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end
end
