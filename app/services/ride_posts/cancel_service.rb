# frozen_string_literal: true

module RidePosts
  class CancelService
    class Error < StandardError; end
    class UnauthorizedError < Error; end

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

        now = Time.current
        ride.update!(status: :canceled)

        ride.bookings.active.find_each do |b|
          b.update!(status: :canceled, canceled_at: now, canceled_by: actor)

          delivery_key = "ride_canceled:#{ride.id}:booking:#{b.id}"
          Notification.find_or_create_by!(delivery_key: delivery_key) do |n|
            n.recipient = b.passenger
            n.actor = actor
            n.notifiable = ride
            n.event_name = "ride.canceled"
            n.delivery_status = :pending
          end
        end

        ride
      end
    end
  end
end
