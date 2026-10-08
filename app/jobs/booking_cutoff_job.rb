# frozen_string_literal: true

class BookingCutoffJob < ApplicationJob
  queue_as :default

  def perform(ride_post_id)
    ride = RidePost.find_by(id: ride_post_id)
    return unless ride

    Bookings::ExpireService.call(ride)
  end
end
