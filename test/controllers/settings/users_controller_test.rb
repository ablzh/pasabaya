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
    assert_match /Cannot delete record because dependent reported trip reviews exist/, flash[:alert]
    assert_not_empty cookies[:session_id]
  end

  test "fails with incorrect password" do
    assert_no_difference("User.count") do
      delete settings_user_url, params: { password_challenge: "wrong_password" }
    end

    assert_redirected_to settings_profile_url
    assert_equal "Incorrect password. Account was not deleted.", flash[:alert]
  end
end
