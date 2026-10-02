# frozen_string_literal: true

class TripAuditJob < ApplicationJob
  queue_as :default

  def perform(ride_post_id)
    ride_post = RidePost.find_by(id: ride_post_id)
    return unless ride_post
    ride_post.with_lock do
      return if ride_post.canceled? || ride_post.draft? || !ride_post.offering?

      arrival_time = ride_post.expected_arrival_at || ride_post.departure_time
      return unless arrival_time.present? && Time.current >= arrival_time + 2.hours

      ride_post.update!(status: :completed) unless ride_post.completed?
      ride_post.bookings.pending.update_all(status: Booking.statuses[:expired], updated_at: Time.current)

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
