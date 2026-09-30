class Notification < ApplicationRecord
  belongs_to :recipient, class_name: "User"
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :notifiable, polymorphic: true

  enum :delivery_status, { pending: 0, delivered: 1, failed: 2 }, default: :pending

  validates :event_name, presence: true
  validates :delivery_key, presence: true, uniqueness: true
  validates :delivery_status, presence: true

  after_create_commit :enqueue_delivery

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  EMAIL_EVENTS = %w[
    booking.requested
    booking.accepted
    booking.canceled
    ride.canceled
    incident.resolved
  ].freeze

  def mark_as_read!
    update!(read_at: Time.current) unless read_at?
  end

  def read?
    read_at.present?
  end

  def deliver!
    reload
    return if delivered?

    if EMAIL_EVENTS.include?(event_name) && recipient&.email_address.present?
      NotificationMailer.with(notification: self).event_notification.deliver_now
    end

    Turbo::StreamsChannel.broadcast_prepend_to(
      [ recipient, :notifications ],
      target: "notifications_list",
      partial: "notifications/notification",
      locals: { notification: self }
    )

    update!(delivery_status: :delivered, delivered_at: Time.current)
  rescue StandardError => e
    if persisted?
      begin
        update_column(:delivery_status, Notification.delivery_statuses[:failed])
      rescue StandardError
        nil
      end
    end
    raise e
  end

  private

  def enqueue_delivery
    NotificationDeliveryJob.perform_later(id)
  end
end
