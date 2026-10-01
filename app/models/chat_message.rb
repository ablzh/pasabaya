# frozen_string_literal: true

class ChatMessage < ApplicationRecord
  belongs_to :ride_post
  belongs_to :user

  validates :body, presence: true, length: { maximum: 1000 }

  validate :participant_must_be_authorized, on: :create
  validate :chat_must_not_be_closed, on: :create

  after_create_commit :broadcast_to_ride_chat
  after_create_commit :broadcast_toast_to_participants

  scope :recent_first, -> { order(created_at: :asc) }

  def self.purge_expired!(older_than = 30.days.ago)
    where("created_at < ?", older_than).destroy_all
  end

  private

  def broadcast_to_ride_chat
    broadcast_append_to [ ride_post, :chat ],
                        target: "chat_messages_list",
                        partial: "chat_messages/chat_message",
                        locals: { chat_message: self }
  end

  def broadcast_toast_to_participants
    ride_post.participants.where.not(id: user_id).find_each do |recipient|
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
  end


  def participant_must_be_authorized
    return unless ride_post && user_id

    unless ride_post.user_authorized_for_chat?(user)
      errors.add(:base, "Only the driver and confirmed passengers can participate in trip chat")
    end
  end

  def chat_must_not_be_closed
    return unless ride_post

    unless ride_post.chat_writable?
      errors.add(:base, "Chat writes are closed 24 hours after trip departure")
    end
  end
end
