# frozen_string_literal: true

require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  setup do
    ActionMailer::Base.deliveries.clear
    @user = users(:one)
    @ride = ride_posts(:one)
  end

  test "deliver! sends email and updates status to delivered" do
    notification = Notification.create!(
      recipient: @user,
      notifiable: @ride,
      event_name: "ride.canceled",
      delivery_key: "single_deliver_test",
      delivery_status: :pending
    )

    assert_emails 1 do
      notification.deliver!
    end

    assert notification.reload.delivered?
    assert notification.delivered_at.present?
  end

  test "deliver! does not send duplicate emails when called on two independently loaded instances" do
    notification = Notification.create!(
      recipient: @user,
      notifiable: @ride,
      event_name: "ride.canceled",
      delivery_key: "concurrent_deliver_test",
      delivery_status: :pending
    )

    inst1 = Notification.find(notification.id)
    inst2 = Notification.find(notification.id)

    # Deliver using first instance
    assert_emails 1 do
      inst1.deliver!
    end

    assert inst1.reload.delivered?

    # Deliver using second instance (which was loaded when status was pending)
    assert_emails 0 do
      inst2.deliver!
    end

    assert inst2.reload.delivered?
  end

  test "deliver! broadcasts toast partial to recipient notifications stream" do
    notification = Notification.create!(
      recipient: @user,
      notifiable: @ride,
      event_name: "booking.accepted",
      delivery_key: "broadcast_deliver_test",
      delivery_status: :pending
    )

    broadcasts = []
    original_broadcast = Turbo::StreamsChannel.method(:broadcast_append_to)
    Turbo::StreamsChannel.define_singleton_method(:broadcast_append_to) do |stream, *args, **kwargs|
      broadcasts << { stream: stream, kwargs: kwargs }
      original_broadcast.call(stream, *args, **kwargs)
    end

    begin
      notification.deliver!
      toast_broadcast = broadcasts.find { |b| b[:stream] == [ @user, :notifications ] && b[:kwargs][:target] == "toast-container" }
      assert_not_nil toast_broadcast
      assert_equal "notifications/toast", toast_broadcast[:kwargs][:partial]
      assert_equal "success", notification.toast_type
      assert_equal "Your seat request has been confirmed!", notification.summary
    ensure
      Turbo::StreamsChannel.define_singleton_method(:broadcast_append_to, original_broadcast)
    end
  end
end
