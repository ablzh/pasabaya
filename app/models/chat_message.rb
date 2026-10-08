# frozen_string_literal: true

class ChatMessage < ApplicationRecord
  belongs_to :ride_post
  belongs_to :user

  validates :body, presence: true, length: { maximum: 1000 }

  before_validation :refresh_creation_context, on: :create

  validate :participant_must_be_authorized, on: :create
  validate :chat_must_not_be_closed, on: :create

  after_create_commit :broadcast_to_ride_chat
  after_create_commit :notify_participants

  scope :recent_first, -> { order(created_at: :asc) }
  scope :latest_for_rides, ->(ride_ids) {
    where(ride_post_id: ride_ids)
      .where("chat_messages.id = (SELECT latest.id FROM chat_messages latest WHERE latest.ride_post_id = chat_messages.ride_post_id ORDER BY latest.created_at DESC, latest.id DESC LIMIT 1)")
  }

  def self.purge_expired!(*_args)
    expired_ride_ids = []
    RidePost.joins(:chat_messages).distinct.find_each do |ride|
      expired_ride_ids << ride.id if ride.chat_expired?
    end
    return [] if expired_ride_ids.empty?

    ChatReadState.where(ride_post_id: expired_ride_ids).destroy_all
    where(ride_post_id: expired_ride_ids).destroy_all
  end

  private

  def refresh_creation_context
    self.user = User.lock.find_by(id: user_id) if user_id
    self.ride_post = RidePost.lock.find_by(id: ride_post_id) if ride_post_id
  end

  def broadcast_to_ride_chat
    broadcast_append_to [ ride_post, :chat ],
                        target: "chat_messages_list",
                        partial: "chat_messages/chat_message",
                        locals: { chat_message: self }
  end

  def notify_participants
    ride_post.participants.find_each do |recipient|
      next unless ride_post.user_authorized_for_chat?(recipient)

      Turbo::StreamsChannel.broadcast_refresh_to([ recipient, :chats ])

      next if recipient.id == user_id

      broadcast_toast_to(recipient)
      ChatReadState.broadcast_unread_count_for(recipient)
    end
  end

  def broadcast_toast_to(recipient)
    role_label = (user_id == ride_post.user_id) ? "Driver" : "Passenger"
    title = "#{user.first_name} (#{role_label})"
    description = body.truncate(75)
    chat_url = Rails.application.routes.url_helpers.ride_post_path(ride_post, tab: "chat")

    Turbo::StreamsChannel.broadcast_append_to(
      [ recipient, :notifications ],
      target: "toast-container",
      partial: "chat_messages/toast",
      locals: {
        title: title,
        description: description,
        action_label: "View Chat",
        action_url: chat_url,
        ride_post_id: ride_post_id
      }
    )
  end

  def participant_must_be_authorized
    return unless ride_post && user_id

    unless ride_post.user_authorized_for_chat?(user)
      errors.add(:base, :not_participant, message: "Only the driver and confirmed passengers can participate in trip chat")
    end
  end

  def chat_must_not_be_closed
    return unless ride_post

    unless ride_post.chat_writable?
      if ride_post.canceled?
        errors.add(:base, :cancellation_closed, message: "Chat writes are closed 24 hours after trip cancellation")
      else
        errors.add(:base, :messaging_closed, message: "Chat writes are closed 24 hours after the booking cutoff")
      end
    end
  end
end
