# frozen_string_literal: true

class ChatReadState < ApplicationRecord
  belongs_to :user
  belongs_to :ride_post

  validates :user_id, presence: true
  validates :ride_post_id, presence: true, uniqueness: { scope: :user_id }
  validates :last_read_message_id, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def self.mark_read!(user:, ride_post:, message_id:)
    message_id = message_id.to_i
    return false if message_id <= 0

    state = find_or_initialize_by(user: user, ride_post: ride_post)
    if state.new_record? || message_id > state.last_read_message_id
      state.last_read_message_id = message_id
      state.save!
      broadcast_unread_count_for(user)
      Turbo::StreamsChannel.broadcast_refresh_to([ user, :chats ])
      true
    else
      false
    end
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
