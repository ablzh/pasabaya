require "application_system_test_case"

class NotificationsSystemTest < ApplicationSystemTestCase
  test "first streamed notification replaces the empty state and updates unread badges" do
    user = users(:one)
    user.received_notifications.destroy_all
    visit new_session_path
    fill_in "Email Address", with: user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_current_path root_path
    visit notifications_path
    assert_text "No notifications yet."
    assert_selector "turbo-cable-stream-source[connected]", visible: :all

    notification = Notification.create!(recipient: user, notifiable: ride_posts(:one),
                                        event_name: "booking.accepted", delivery_key: "first_streamed_notification")
    notification.deliver!
    assert_selector "#notifications_list .notification", text: "Your seat request has been confirmed!"
    assert_no_text "No notifications yet."
    assert_selector "[data-notification-count] span", text: "1"

    notification.mark_as_read!
    assert_no_selector "[data-notification-count] span", visible: :all
  end
end
