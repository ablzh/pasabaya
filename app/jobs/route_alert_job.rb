# frozen_string_literal: true

class RouteAlertJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(ride_post_id)
    # Snapshot before matching: a concurrent edit must retain its own work even
    # if it commits while this job is processing an earlier version of the ride.
    dispatch_ids = RidePostDispatch.route_alert.where(ride_post_id: ride_post_id).pluck(:id)
    ride = RidePost.find_by(id: ride_post_id)
    RouteSubscriptions::MatchService.call(ride) if ride
    RidePostDispatch.where(id: dispatch_ids).delete_all
  rescue StandardError => error
    RidePostDispatch.record_failure(dispatch_ids || [], error)
    raise
  end
end
