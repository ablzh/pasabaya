class RideCancellationBroadcastJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(dispatch_id) { "ride_cancellation_broadcast_#{dispatch_id}" }
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(dispatch_id)
    dispatch = RidePostDispatch.cancellation_refresh.includes(:ride_post).find_by(id: dispatch_id)
    return unless dispatch

    ride = dispatch.ride_post
    if ride.canceled?
      Turbo::StreamsChannel.broadcast_refresh_to([ ride, :chat ])
      User.where(id: dispatch.recipient_ids).find_each do |recipient|
        Turbo::StreamsChannel.broadcast_refresh_to([ recipient, :chats ])
      end
    end
    dispatch.destroy!
  rescue StandardError => error
    RidePostDispatch.record_failure([ dispatch_id ], error)
    raise
  end
end
