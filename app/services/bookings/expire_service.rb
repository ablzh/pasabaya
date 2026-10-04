# frozen_string_literal: true

module Bookings
  class ExpireService
    class Error < StandardError; end
    class InvalidStateError < Error; end

    MAX_RETRIES = 3

    def self.call(...)
      new(...).call
    end

    def initialize(target)
      @target = target
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

    attr_reader :target

    def execute_transaction
      if target.is_a?(Booking)
        expire_single_booking(target.id)
      elsif target.is_a?(RidePost)
        expire_ride_post_bookings(target.id)
      end
    end

    def expire_single_booking(booking_id)
      ActiveRecord::Base.transaction do
        b = Booking.lock.find_by(id: booking_id)
        return unless b && b.pending?

        ride = RidePost.lock.find_by(id: b.ride_post_id)
        return unless ride && (ride.requests_closed_at.present? || (ride.booking_cutoff_at.present? && Time.current >= ride.booking_cutoff_at))

        expire_booking_record(b)
      end
    end

    def expire_ride_post_bookings(ride_post_id)
      # Find pending booking IDs first, then process each with proper lock ordering
      ride = RidePost.find_by(id: ride_post_id)
      return unless ride && (ride.requests_closed_at.present? || (ride.booking_cutoff_at.present? && Time.current >= ride.booking_cutoff_at))

      booking_ids = ride.bookings.pending.order(:id).pluck(:id)
      booking_ids.each do |b_id|
        expire_single_booking(b_id)
      end
    end

    def expire_booking_record(booking)
      booking.update!(status: :expired)

      delivery_key = "booking_expired:#{booking.id}"
      Notification.find_or_create_by!(delivery_key: delivery_key) do |n|
        n.recipient = booking.passenger
        n.actor = nil
        n.notifiable = booking
        n.event_name = "booking.expired"
        n.delivery_status = :pending
      end
    end
  end
end
