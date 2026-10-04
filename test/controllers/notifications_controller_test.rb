require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @notification = notifications(:one)
  end

  test "avatar contains the accessible notification badge and a compact profile menu" do
    sign_in_as(@user)
    get root_url
    assert_select "nav > div > ul a[href='#{notifications_path}']", count: 0
    assert_select "button[aria-label='Account menu'][aria-describedby='account-notification-count'] [data-notification-count] span[aria-label='1 unread notification']", text: "1"
    assert_select "#profile-content a", count: 4
    { "Profile" => user_path(@user), "Settings" => settings_profile_path,
      "Notifications" => notifications_path, "Sign out" => session_path }.each do |label, path|
      assert_select "#profile-content a[href='#{path}']", text: /#{label}/
    end
    assert_select "#profile-content a[href='#{trips_path}']", count: 0
    assert_select "#profile-content a[href='#{communities_path}']", count: 0
    assert_select "nav a[href='#{communities_path}']"
    assert_select "nav a[href='#{chats_path}']"
  end

  test "authenticated user can view their notifications" do
    sign_in_as(@user)

    get notifications_url
    assert_response :success
  end

  test "viewing a notification marks it as read and redirects to target" do
    sign_in_as(@user)
    assert_not @notification.read?

    get notification_url(@notification)

    assert @notification.reload.read?
    assert_redirected_to ride_post_url(@notification.notifiable.ride_post)
  end

  test "unauthenticated user cannot access notifications" do
    get notifications_url
    assert_redirected_to new_session_url
  end

  test "marking a notification read with HTML redirects using GET" do
    sign_in_as(@user)
    patch mark_as_read_notification_url(@notification)
    assert_response :see_other
    assert_redirected_to notifications_url
    assert @notification.reload.read?
  end

  test "viewing a notification when notifiable was deleted redirects to rides index" do
    sign_in_as(@user)
    ride = RidePost.create!(
      user: users(:two),
      origin: locations(:one),
      destination: locations(:two),
      post_type: :offering,
      seats: 2,
      departure_time: 2.days.from_now,
      expected_arrival_at: 2.days.from_now + 2.hours,
      status: :active
    )
    orphan_notification = Notification.create!(
      recipient: @user,
      notifiable: ride,
      event_name: "ride.canceled",
      delivery_key: "orphan_test_key",
      delivery_status: :delivered
    )
    ride.destroy!

    get notification_url(orphan_notification)

    assert orphan_notification.reload.read?
    assert_redirected_to ride_posts_url
    assert_equal "The trip is no longer available.", flash[:notice]
  end
end
