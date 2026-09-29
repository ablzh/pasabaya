# frozen_string_literal: true

class PurgeOldChatMessagesJob < ApplicationJob
  queue_as :default

  def perform(older_than_days = 30)
    cutoff = older_than_days.to_i.days.ago
    ChatMessage.where("created_at < ?", cutoff).destroy_all
  end
end
