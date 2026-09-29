require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @notification = notifications(:one)
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
end
