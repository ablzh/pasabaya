class TripAuditRecoveryJob < ApplicationJob
  queue_as :default

  def perform
    RidePost.offering.where(status: [ :active, :fulfilled, :completed ]).where("departure_time <= ? OR (departure_time IS NULL AND departure_date <= ?)", Time.current, Date.current).find_each do |ride|
      TripAuditJob.perform_later(ride.id) if ride.automatic_completion_at && ride.automatic_completion_at <= Time.current
    end
  end
end
