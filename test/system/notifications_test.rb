require "application_system_test_case"

class NotificationsSystemTest < ApplicationSystemTestCase
  test "notification row and keyboard link open the target and mark it read" do
    page.driver.resize(320, 844)
    visit new_session_path
    fill_in "Email Address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_current_path root_path
    notification = notifications(:one)
    target_path = ride_post_path(notification.notifiable.ride_post)
    %i[row keyboard].each do |interaction|
      notification.update_columns(read_at: nil)
      visit notifications_path
      assert_selector "#notification_#{notification.id}[data-unread-notification='true']"
      if interaction == :row
        find("#notification_#{notification.id}").click(x: 12, y: 12)
      else
        find("#notification_#{notification.id} a").execute_script("this.focus()")
        page.driver.browser.keyboard.type(:Enter)
      end
      assert_current_path target_path
      Prosopite.pause { assert notification.reload.read? }
    end
  end

  test "mark all read updates an open notification list and every count" do
    user = users(:one)
    visit new_session_path
    fill_in "Email Address", with: user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_current_path root_path
    visit notifications_path
    assert_selector "turbo-cable-stream-source[connected]", visible: :all
    assert_selector "[data-unread-notification='true']"
    user.mark_all_notifications_as_read!
    assert_no_selector "[data-unread-notification='true']"
    assert_no_selector "[data-notification-count] span", visible: :all
  end

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
    assert_selector "button[aria-label='Account menu'] [data-notification-count] span[aria-label='1 unread notification']", text: "1"
    assert_selector "#profile-content [data-notification-count] span[aria-label='1 unread notification']", text: "1", visible: :all

    notification.mark_as_read!
    assert_no_selector "[data-notification-count] span", visible: :all
  end
end
