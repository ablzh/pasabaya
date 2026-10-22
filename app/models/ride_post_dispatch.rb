class RidePostDispatch < ApplicationRecord
  belongs_to :ride_post

  enum :operation, { route_alert: "route_alert", cancellation_refresh: "cancellation_refresh" }, validate: true
  validates :operation, presence: true

  after_create_commit :enqueue

  # Rows remain until the work succeeds, including when a process stops between
  # the primary commit and enqueueing into the separate queue database.
  def enqueue
    job = if route_alert?
      RouteAlertJob.perform_later(ride_post_id)
    else
      RideCancellationBroadcastJob.perform_later(id)
    end
    raise ActiveJob::EnqueueError, "Dispatch was not enqueued" unless job
  rescue StandardError => error
    self.class.record_failure([ id ], error)
  end

  def self.record_failure(ids, error)
    where(id: ids).update_all([ "failure_count = failure_count + 1, last_error = ?, failed_at = ?", error.class.name, Time.current ])
  rescue StandardError => tracking_error
    Rails.logger.error("RidePostDispatch failure recording failed error=#{tracking_error.class.name}")
  ensure
    Rails.logger.error("RidePostDispatch failed ids=#{ids.join(',')} error=#{error.class.name}")
  end
end
