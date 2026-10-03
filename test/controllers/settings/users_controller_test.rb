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

  test "deletes account with valid password when unconstrained" do
    assert_difference("User.count", -1) do
      delete settings_user_url, params: { password_challenge: "password" }
    end

    assert_redirected_to root_url
    assert_equal "Your account has been deleted.", flash[:notice]
    assert_empty cookies[:session_id]
  end

  test "fails to delete account and preserves session when user has trip reviews" do
    driver = users(:one)
    ride = ride_posts(:one)
    Booking.create!(ride_post: ride, passenger: @user, status: :accepted)
    ride.update_columns(departure_time: 2.hours.ago, expected_arrival_at: 1.hour.ago)

    TripReview.create!(
      ride_post: ride,
      reporter: @user,
      reported_user: driver,
      outcome: :completed
    )

    assert_no_difference("User.count") do
      delete settings_user_url, params: { password_challenge: "password" }
    end

    assert_redirected_to settings_profile_url
    assert_response :see_other
    assert_match /Cannot delete record because dependent reported trip reviews exist/, flash[:alert]
    assert_not_empty cookies[:session_id]
  end

  test "fails with incorrect password" do
    assert_no_difference("User.count") do
      delete settings_user_url, params: { password_challenge: "wrong_password" }
    end

    assert_redirected_to settings_profile_url
    assert_response :see_other
    assert_equal "Incorrect password. Account was not deleted.", flash[:alert]
  end

  test "fails to delete account when driver has departed ride with historical participation" do
    ride = ride_posts(:one)
    booking = bookings(:one)
    ride.update_columns(user_id: @user.id, departure_time: 2.hours.ago, expected_arrival_at: 1.hour.ago)
    booking.update_columns(status: Booking.statuses[:accepted], accepted_at: 3.hours.ago)

    assert_no_difference "User.count" do
      delete settings_user_url, params: { password_challenge: "password" }
    end

    assert_redirected_to settings_profile_url
    assert_match /Cannot delete account with departed rides that retain historical participation/, flash[:alert]
    assert_not_empty cookies[:session_id]
    assert User.exists?(@user.id)
    assert RidePost.exists?(ride.id)
  end

  test "fails to delete account when passenger has historical participation on departed ride" do
    ride = ride_posts(:one)
    booking = bookings(:one)
    booking.update_columns(passenger_id: @user.id, status: Booking.statuses[:accepted], accepted_at: 3.hours.ago)
    ride.update_columns(departure_time: 2.hours.ago, expected_arrival_at: 1.hour.ago)

    assert_no_difference "User.count" do
      delete settings_user_url, params: { password_challenge: "password" }
    end

    assert_redirected_to settings_profile_url
    assert_match /Cannot delete account with historical trip participation/, flash[:alert]
    assert_not_empty cookies[:session_id]
    assert User.exists?(@user.id)
  end
end
