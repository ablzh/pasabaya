# frozen_string_literal: true

require "test_helper"

class NotificationRecoveryJobTest < ActiveJob::TestCase
  setup do
    @recipient = users(:one)
    @notification = Notification.create!(
      recipient: @recipient,
      actor: users(:two),
      notifiable: bookings(:one),
      event_name: "booking.accepted",
      delivery_key: "recovery_test_#{SecureRandom.hex(6)}",
      delivery_status: :failed
    )
  end

  test "enqueues delivery for failed or pending notifications" do
    assert_enqueued_with(job: NotificationDeliveryJob, args: [ @notification.id ]) do
      NotificationRecoveryJob.perform_now
    end
  end
end
