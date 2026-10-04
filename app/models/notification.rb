class Notification < ApplicationRecord
  belongs_to :recipient, class_name: "User"
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :notifiable, polymorphic: true
  belongs_to :route_subscription, optional: true

  enum :delivery_status, { pending: 0, delivered: 1, failed: 2 }, default: :pending

  validates :event_name, presence: true
  validates :delivery_key, presence: true, uniqueness: true
  validates :delivery_status, presence: true

  after_create_commit :enqueue_delivery
  after_update_commit :broadcast_unread_count, if: :saved_change_to_read_at?

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  EMAIL_EVENTS = %w[
    booking.requested
    booking.accepted
    booking.canceled
    ride.canceled
    incident.resolved
    route.alert
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
    when "booking.expired"
      "Your seat request expired without confirmation"
    when "route.alert"
      "A driver posted a matching ride for your route alert!"
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
    when "booking.accepted", "route.alert"
      "success"
    when "booking.canceled", "ride.canceled", "booking.declined", "booking.expired"
      "warning"
    else
      "info"
    end
  end

  def route_alert_available?
    return true unless event_name == "route.alert"

    ride = notifiable
    subscription = route_subscription
    ride.is_a?(RidePost) && subscription.present? && subscription.fulfilled? &&
      subscription.user_id == recipient_id && subscription.ride_post_id == ride.id &&
      subscription.matches_ride?(ride.reload)
  end

  def deliver!
    with_lock do
      return if delivered?
      return unless route_alert_available?

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
      broadcast_unread_count
    end

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

  def broadcast_unread_count
    Turbo::StreamsChannel.broadcast_update_to(
      [ recipient, :notifications ],
      targets: "[data-notification-count]",
      partial: "notifications/count",
      locals: { count: recipient.received_notifications.unread.count }
    )
  end

  def enqueue_delivery
    NotificationDeliveryJob.perform_later(id)
  end
end
