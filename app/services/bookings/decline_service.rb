# frozen_string_literal: true

module Bookings
  class DeclineService
    class Error < StandardError; end
    class UnauthorizedError < Error; end
    class InvalidStateError < Error; end

    def self.call(...)
      new(...).call
    end

    def initialize(booking, actor:)
      @booking = booking
      @actor = actor
    end

    def call
      ActiveRecord::Base.transaction do
        b = Booking.lock.find(booking.id)
        ride = RidePost.lock.find(b.ride_post_id)

        unless ride.user_id == actor.id
          raise UnauthorizedError, "Only the driver can decline booking requests"
        end

        return b if b.declined?

        unless b.pending?
          raise InvalidStateError, "Only pending bookings can be declined"
        end

        now = Time.current
        b.update!(status: :declined, decided_at: now)

        delivery_key = "booking_declined:#{b.id}:#{now.to_i}"
        Notification.find_or_create_by!(delivery_key: delivery_key) do |n|
          n.recipient = b.passenger
          n.actor = actor
          n.notifiable = b
          n.event_name = "booking.declined"
          n.delivery_status = :pending
        end

        b
      end
    end

    private

    attr_reader :booking, :actor
  end
end
