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

    def self.call_many(rides, actor:)
      ActiveRecord::Base.transaction do
        locked = RidePost.where(id: rides.select(:id)).lock.includes(:user, :origin, :destination, :community, bookings: :passenger).to_a
        active = locked.flat_map { |ride| ride.bookings.select(&:active?).map { |booking| [ ride, booking ] } }
        keys = active.map { |ride, booking| "ride_canceled:#{ride.id}:booking:#{booking.id}" }
        existing_keys = Notification.where(delivery_key: keys).pluck(:delivery_key).to_set
        recipients = []
        locked.each do |ride|
          recipients.concat(cancel_locked_ride(ride, actor, existing_keys))
        end
        recipients.uniq(&:id).each do |recipient|
          Turbo::StreamsChannel.broadcast_refresh_to([ recipient, :chats ])
        end
        locked
      end
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
      self.class.call_many(RidePost.where(id: ride_post.id), actor: actor).first || raise(ActiveRecord::RecordNotFound)
    end

    def self.cancel_locked_ride(ride, actor, existing_keys)
      unless ride.user_id == actor.id
        raise UnauthorizedError, "Only the driver can cancel this ride"
      end
      return [] if ride.canceled?
      raise InvalidStateError, "Completed trips cannot be canceled" if ride.completed?

      active_bookings = ride.bookings.select(&:active?)
      recipients = [ ride.user ] + active_bookings.select(&:accepted?).map(&:passenger)
      now = Time.current
      ride.update!(status: :canceled, canceled_at: ride.canceled_at || now)
      active_bookings.each do |booking|
        accepted_at = booking.accepted_at || (booking.accepted? ? booking.decided_at || booking.created_at : nil)
        # The primary write transaction owns the loaded states. Preserve historical
        # acceptance while cancelling participation without per-record lookups.
        booking.update_columns(status: Booking.statuses[:canceled], canceled_at: now, canceled_by_id: actor.id,
          accepted_at: accepted_at, updated_at: now)
        key = "ride_canceled:#{ride.id}:booking:#{booking.id}"
        next if existing_keys.include?(key)

        Notification.create!(delivery_key: key, recipient: booking.passenger, actor: actor,
          notifiable: ride, event_name: "ride.canceled", delivery_status: :pending)
      end
      recipients
    end

    private_class_method :cancel_locked_ride
  end
end
