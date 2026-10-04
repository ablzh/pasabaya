# frozen_string_literal: true

class ChatReadState < ApplicationRecord
  belongs_to :user
  belongs_to :ride_post

  validates :user_id, presence: true
  validates :ride_post_id, presence: true, uniqueness: { scope: :user_id }
  validates :last_read_message_id, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def self.mark_read!(user:, ride_post:, message_id:)
    return false unless message_id.to_s.match?(/\A[1-9]\d*\z/)

    message_id = message_id.to_i
    return false if message_id <= 0 || !ride_post.chat_messages.exists?(id: message_id)

    insert_all([ { user_id: user.id, ride_post_id: ride_post.id, last_read_message_id: 0 } ], unique_by: [ :user_id, :ride_post_id ])
    changed = where(user_id: user.id, ride_post_id: ride_post.id)
              .where("last_read_message_id < ?", message_id)
              .update_all(last_read_message_id: message_id, updated_at: Time.current)
    if changed.positive?
      broadcast_unread_count_for(user)
      Turbo::StreamsChannel.broadcast_refresh_to([ user, :chats ])
    end
    changed.positive?
  end

  def self.broadcast_unread_count_for(user)
    count = user.unread_chats_count
    Turbo::StreamsChannel.broadcast_update_to(
      [ user, :notifications ],
      targets: "[data-chat-unread-count]",
      partial: "chats/unread_badge",
      locals: { count: count }
    )
  end
end
