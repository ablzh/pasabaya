# frozen_string_literal: true

module RidePosts
  class CancelService
    class Error < StandardError; end
    class UnauthorizedError < Error; end
    class InvalidStateError < Error; end

    MAX_RETRIES = 3

    def self.call(...)
      new(...).call
    end

    def initialize(ride_post, actor:)
      @ride_post = ride_post
      @actor = actor
    end

    def call
      retries = 0
      begin
        execute_transaction
      rescue ActiveRecord::Deadlocked, ActiveRecord::StatementInvalid => e
        if (retries += 1) <= MAX_RETRIES && e.message.include?("busy")
          sleep(0.05 * retries)
          retry
        else
          raise
        end
      end
    end

    private

    attr_reader :ride_post, :actor

    def execute_transaction
      ActiveRecord::Base.transaction do
        ride = RidePost.lock.find(ride_post.id)

        unless ride.user_id == actor.id
          raise UnauthorizedError, "Only the driver can cancel this ride"
        end

        return ride if ride.canceled?
        raise InvalidStateError, "Completed trips cannot be canceled" if ride.completed?

        now = Time.current
        ride.update!(status: :canceled, canceled_at: ride.canceled_at || now)

        active_bookings = ride.bookings.active.includes(:passenger).to_a
        keys = active_bookings.map { |b| "ride_canceled:#{ride.id}:booking:#{b.id}" }
        existing_keys = Notification.where(delivery_key: keys).pluck(:delivery_key).to_set

        active_bookings.each do |b|
          b.update!(status: :canceled, canceled_at: now, canceled_by: actor,
                    accepted_at: b.accepted_at || (b.accepted? ? b.decided_at || b.created_at : nil))

          delivery_key = "ride_canceled:#{ride.id}:booking:#{b.id}"
          next if existing_keys.include?(delivery_key)

          Notification.create!(
            delivery_key: delivery_key,
            recipient: b.passenger,
            actor: actor,
            notifiable: ride,
            event_name: "ride.canceled",
            delivery_status: :pending
          )
        end

        ride.participants.find_each do |recipient|
          Turbo::StreamsChannel.broadcast_refresh_to([ recipient, :chats ])
        end

        ride
      end
    end
  end
end
