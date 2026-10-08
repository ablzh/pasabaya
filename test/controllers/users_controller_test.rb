# frozen_string_literal: true

require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "profile renders external Facebook link" do
    sign_in_as(users(:one))
    get user_url(users(:one))

    assert_response :success
    assert_select "a[href='https://facebook.com/juan'][target='_blank'][rel='noopener noreferrer']"
  end

  test "owner viewing own profile sees activity tabs including joined trips" do
    passenger = users(:two)
    sign_in_as(passenger)

    get user_url(passenger)

    assert_response :success
    assert_select "a[href='#{user_path(passenger, tab: 'posts')}']", text: /My Posts/
    assert_select "a[href='#{user_path(passenger, tab: 'bookings')}']", text: /Joined Trips/
  end

  test "legacy unsafe Facebook URLs are not rendered as links" do
    user = users(:one)
    user.update_columns(facebook_profile_url: "javascript:alert(1)")
    sign_in_as(user)
    get user_url(user)
    assert_response :success
    assert_select "a[href^='javascript:']", count: 0
  end

  test "owner viewing bookings tab sees accepted booking with chat link" do
    passenger = users(:two)
    booking = bookings(:one)
    booking.update_columns(status: Booking.statuses[:accepted])

    sign_in_as(passenger)
    get user_url(passenger, tab: "bookings")

    assert_response :success
    assert_select "a[href='#{ride_post_path(booking.ride_post, tab: 'chat')}']", text: /Trip Chat/
  end

  test "stranger viewing someone else's profile only sees public active posts" do
    driver = users(:one)
    stranger = users(:two)
    sign_in_as(stranger)

    get user_url(driver)

    assert_response :success
    assert_select "h2", text: "Active Posts"
    assert_select "a[href='#{user_path(driver, tab: 'bookings')}']", count: 0
  end

  test "owner can find full rides drafts and completed history" do
    owner = users(:one)
    ride = ride_posts(:one)
    sign_in_as(owner)
    %i[fulfilled draft completed].each do |status|
      ride.update_columns(status: RidePost.statuses[status])
      get user_url(owner)
      assert_response :success
      assert_select "#ride_post_#{ride.id}"
    end

    sign_in_as(users(:two))
    get user_url(owner)
    assert_select "#ride_post_#{ride.id}", count: 0
  end
end
