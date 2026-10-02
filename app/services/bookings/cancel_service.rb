# frozen_string_literal: true

module Bookings
  class CancelService
    class Error < StandardError; end
    class UnauthorizedError < Error; end
    class InvalidStateError < Error; end

    MAX_RETRIES = 3

    def self.call(...)
      new(...).call
    end

    def initialize(booking, actor:)
      @booking = booking
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

    attr_reader :booking, :actor

    def execute_transaction
      ActiveRecord::Base.transaction do
        b = Booking.lock.find(booking.id)
        ride = RidePost.lock.find(b.ride_post_id)

        is_passenger = (b.passenger_id == actor.id)
        is_driver = (ride.user_id == actor.id)

        unless is_passenger || is_driver
          raise UnauthorizedError, "Only the passenger or driver can cancel this booking"
        end

        return b if b.canceled?

        unless b.active?
          raise InvalidStateError, "Only active (pending or accepted) bookings can be canceled"
        end

        was_accepted = b.accepted?
        now = Time.current

        b.update!(status: :canceled, canceled_at: now, canceled_by: actor,
                  accepted_at: b.accepted_at || (was_accepted ? b.decided_at || b.created_at : nil))

        if was_accepted
          new_remaining = [ ride.remaining_seats + 1, ride.seats ].min
          ride_attributes = { remaining_seats: new_remaining }

          if ride.fulfilled? && ride.departure_time.present? && ride.departure_time > Time.current
            ride_attributes[:status] = :active
          end

          ride.update!(ride_attributes)
        end

        recipient = is_passenger ? ride.user : b.passenger
        delivery_key = "booking_canceled:#{b.id}:#{now.to_i}"
        Notification.find_or_create_by!(delivery_key: delivery_key) do |n|
          n.recipient = recipient
          n.actor = actor
          n.notifiable = ride
          n.event_name = "booking.canceled"
          n.delivery_status = :pending
        end

        b
      end
    end
  end
end
