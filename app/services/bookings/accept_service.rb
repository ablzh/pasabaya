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
          raise InvalidStateError, "Only pending bookings can be accepted (current: #{b.status})"
        end

        if ride.requests_closed_at.present?
          raise InvalidStateError, "The driver has closed seat requests"
        end

        if ride.booking_cutoff_at.blank? || ride.booking_cutoff_at <= Time.current
          raise InvalidStateError, "Cannot accept bookings for rides in the past"
        end

        unless ride.published?
          raise InvalidStateError, "Ride is not published and accepting bookings"
        end

        ride.user.reload
        unless ride.driver_eligible?
          raise InvalidStateError, "Driver is no longer eligible to accept bookings for this ride"
        end

        unless b.passenger.eligible_for_booking?
          raise InvalidStateError, "Passenger is no longer eligible for booking"
        end

        unless ride.authorized_for_booking?(b.passenger)
          raise InvalidStateError, "Passenger is no longer eligible for this ride's audience"
        end

        if ride.remaining_seats.to_i <= 0
          raise CapacityError, "No remaining seats available on this ride"
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
