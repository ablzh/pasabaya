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

  def summary
    case event_name
    when "booking.requested"
      "#{actor&.first_name || 'A passenger'} requested a seat on your ride."
    when "booking.accepted"
      "Your seat request has been confirmed!"
    when "booking.declined"
      "Your seat request was declined by the driver."
    when "booking.canceled"
      "#{actor&.first_name || 'A user'} canceled their seat booking."
    when "ride.canceled"
      "A ride you had booked has been canceled by the driver."
    when "review.requested"
      "Please review your recent trip."
    when "incident.resolved"
      "An incident report was resolved."
    else
      event_name.humanize
    end
  end

  def toast_type
    case event_name
    when "booking.accepted"
      "success"
    when "booking.canceled", "ride.canceled", "booking.declined"
      "warning"
    else
      "info"
    end
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

    Turbo::StreamsChannel.broadcast_append_to(
      [ recipient, :notifications ],
      target: "toast-container",
      partial: "notifications/toast",
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
