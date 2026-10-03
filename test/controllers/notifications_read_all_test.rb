require "test_helper"

class NotificationsReadAllTest < ActionDispatch::IntegrationTest
  test "a notification arriving after the snapshot remains unread" do
    user = users(:one)
    sign_in_as(user)
    incoming = nil
    capturing = false
    observer = ->(_name, _start, _finish, _id, payload) do
      if !capturing && incoming.nil? && payload[:sql].include?('MAX("notifications"."id")')
        capturing = true
        incoming = Notification.create!(recipient: user, notifiable: ride_posts(:one), event_name: "booking.accepted", delivery_key: "after-snapshot")
      end
    end
    ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
      patch mark_all_as_read_notifications_url
    end
    assert incoming
    assert_not incoming.reload.read?
    assert notifications(:one).reload.read?
  end

  test "read all includes older undisplayed entries and affects only recipient" do
    user = users(:one)
    sign_in_as(user)
    old = Notification.create!(recipient: user, notifiable: ride_posts(:one), event_name: "booking.accepted", delivery_key: "older-unread", created_at: 1.year.ago)
    51.times do |i|
      Notification.create!(recipient: user, notifiable: ride_posts(:one), event_name: "booking.accepted", delivery_key: "unread-#{i}")
    end
    other = Notification.create!(recipient: users(:two), notifiable: ride_posts(:one), event_name: "booking.accepted", delivery_key: "other-unread")
    patch mark_all_as_read_notifications_url
    assert_redirected_to notifications_url
    assert old.reload.read?
    assert_equal 0, user.received_notifications.unread.count
    assert_not other.reload.read?
    patch mark_all_as_read_notifications_url
    assert_response :see_other
  end
end
