# frozen_string_literal: true

class TripAuditJob < ApplicationJob
  queue_as :default

  def perform(ride_post_id)
    ride_post = RidePost.find_by(id: ride_post_id)
    return unless ride_post
    ride_post.with_lock do
      return if ride_post.canceled? || ride_post.draft? || !ride_post.offering?

      completion_time = ride_post.automatic_completion_at
      return unless completion_time.present? && Time.current >= completion_time

      ride_post.update!(status: :completed) unless ride_post.completed?
      Bookings::ExpireService.call(ride_post)

      participants = ride_post.review_participants
      participant_keys = participants.map { |p| "review_requested:#{ride_post.id}:#{p.id}" }
      existing_keys = Notification.where(delivery_key: participant_keys).pluck(:delivery_key).to_set

      participants.each do |participant|
        delivery_key = "review_requested:#{ride_post.id}:#{participant.id}"
        next if existing_keys.include?(delivery_key)

        Notification.create!(
          delivery_key: delivery_key,
          recipient: participant,
          actor: nil,
          notifiable: ride_post,
          event_name: "review.requested",
          delivery_status: :pending
        )
      end
    end
  end
end
