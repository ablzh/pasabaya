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
end
