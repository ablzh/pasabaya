class TripAuditRecoveryJob < ApplicationJob
  queue_as :default

  def perform
    RidePost.offering.where(status: [ :active, :fulfilled, :completed ]).where("departure_time <= ?", Time.current).find_each do |ride|
      TripAuditJob.perform_later(ride.id) if ride.automatic_completion_at && ride.automatic_completion_at <= Time.current
    end
  end
end
