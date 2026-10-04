# frozen_string_literal: true

class RouteAlertJob < ApplicationJob
  queue_as :default

  def perform(ride_post_id)
    ride = RidePost.find_by(id: ride_post_id)
    return unless ride

    RouteSubscriptions::MatchService.call(ride)
  end
end
