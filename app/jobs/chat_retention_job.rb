# frozen_string_literal: true

class ChatRetentionJob < ApplicationJob
  queue_as :default

  def perform(ride_post_id)
    ride = RidePost.find_by(id: ride_post_id)
    return unless ride
    return unless ride.chat_expired?

    ride.chat_messages.destroy_all
  end
end
