# frozen_string_literal: true

class PurgeOldChatMessagesJob < ApplicationJob
  queue_as :default

  def perform(*_args)
    ChatMessage.purge_expired!
  end
end
