# frozen_string_literal: true

class ChatMessage < ApplicationRecord
  belongs_to :ride_post
  belongs_to :user

  validates :body, presence: true, length: { maximum: 1000 }

  validate :participant_must_be_authorized, on: :create
  validate :chat_must_not_be_closed, on: :create

  after_create_commit :broadcast_to_ride_chat

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
