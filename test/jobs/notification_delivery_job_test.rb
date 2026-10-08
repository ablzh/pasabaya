# frozen_string_literal: true

require "test_helper"

class NotificationDeliveryJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper
  setup do
    @recipient = users(:one)
    @actor = users(:two)
    @booking = bookings(:one)
    @notification = Notification.create!(
      recipient: @recipient,
      actor: @actor,
      notifiable: @booking,
      event_name: "booking.accepted",
      delivery_key: "test_delivery_#{SecureRandom.hex(6)}",
      delivery_status: :pending
    )
  end

  test "delivers pending notification and sends email for email events" do
    assert_emails 1 do
      NotificationDeliveryJob.perform_now(@notification.id)
    end

    @notification.reload
    assert_equal "delivered", @notification.delivery_status
    assert_not_nil @notification.delivered_at
  end

  test "skips delivery if already delivered" do
    @notification.update_columns(delivery_status: Notification.delivery_statuses[:delivered], delivered_at: Time.current)

    assert_emails 0 do
      NotificationDeliveryJob.perform_now(@notification.id)
    end
  end
end
