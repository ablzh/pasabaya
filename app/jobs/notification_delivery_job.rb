# frozen_string_literal: true

class NotificationDeliveryJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(notification_id) { "notification_delivery_#{notification_id}" }

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(notification_id)
    notification = Notification.find_by(id: notification_id)
    return unless notification
    return if notification.delivered?

    notification.deliver!
  end
end
