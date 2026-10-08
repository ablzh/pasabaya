# frozen_string_literal: true

module Bookings
  class CreateService
    def self.call(ride_post:, passenger:, pickup_notes: nil)
      Booking.transaction do
        booking = Booking.create!(ride_post: ride_post, passenger: passenger, pickup_notes: pickup_notes)
        ride = booking.ride_post

        Notification.create!(
          delivery_key: "booking_requested:#{booking.id}",
          recipient: ride.user,
          actor: booking.passenger,
          notifiable: booking,
          event_name: "booking.requested",
          delivery_status: :pending
        )

        BookingCutoffJob.set(wait_until: ride.booking_cutoff_at).perform_later(ride.id)
        booking
      end
    end
  end
end
