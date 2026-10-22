# frozen_string_literal: true

module Bookings
  class AcceptService
    class Error < StandardError; end
    class UnauthorizedError < Error; end
    class InvalidStateError < Error; end
    class CapacityError < Error; end

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

        unless ride.user_id == actor.id
          raise UnauthorizedError, "Only the driver can accept booking requests"
        end

        return b if b.accepted?

        unless b.pending?
          raise InvalidStateError, "This seat request is no longer pending and can’t be accepted"
        end

        ride.user.reload
        case ride.booking_unavailability_reason
        when :unpublished
          raise InvalidStateError, "Ride is not published and accepting bookings"
        when :full
          raise CapacityError, "No remaining seats available on this ride"
        when :requests_closed
          raise InvalidStateError, "The driver has closed seat requests"
        when :departed
          raise InvalidStateError, "Cannot accept bookings for rides in the past"
        when :driver_ineligible
          raise InvalidStateError, "Driver is no longer eligible to accept bookings for this ride"
        when :schedule_unavailable
          raise InvalidStateError, "This regular schedule is not accepting requests for this date"
        end

        unless b.passenger.eligible_for_booking?
          raise InvalidStateError, "Passenger is no longer eligible for booking"
        end

        unless ride.authorized_for_booking?(b.passenger)
          raise InvalidStateError, "Passenger is no longer eligible for this ride's audience"
        end

        now = Time.current
        b.update!(status: :accepted, decided_at: now)

        new_remaining = ride.remaining_seats - 1
        ride_attributes = { remaining_seats: new_remaining }
        ride_attributes[:status] = :fulfilled if new_remaining.zero?
        ride.update!(ride_attributes)

        delivery_key = "booking_accepted:#{b.id}:#{now.to_i}"
        Notification.find_or_create_by!(delivery_key: delivery_key) do |n|
          n.recipient = b.passenger
          n.actor = actor
          n.notifiable = b
          n.event_name = "booking.accepted"
          n.delivery_status = :pending
        end

        b
      end
    end
  end
end
