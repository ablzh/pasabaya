class TripAuditRecoveryJob < ApplicationJob
  queue_as :default

  def perform
    RouteSubscription.expire_overdue!

    # Completion and its review events commit together; completed rides need no replay.
    RidePost.offering.where(status: [ :active, :fulfilled ]).where("departure_time <= ? OR (departure_time IS NULL AND departure_date <= ?)", Time.current, Date.current).find_each do |ride|
      Bookings::ExpireService.call(ride) if ride.booking_cutoff_at && ride.booking_cutoff_at <= Time.current
      TripAuditJob.perform_later(ride.id) if ride.automatic_completion_at && ride.automatic_completion_at <= Time.current
    end

    ChatMessage.purge_expired!
  end
end
