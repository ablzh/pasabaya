# frozen_string_literal: true

class NotificationRecoveryJob < ApplicationJob
  queue_as :default

  def perform
    Notification.where(delivery_status: [ :pending, :failed ])
                .where("created_at > ?", 48.hours.ago)
                .find_each do |notification|
      NotificationDeliveryJob.perform_later(notification.id)
    end
  end
end
