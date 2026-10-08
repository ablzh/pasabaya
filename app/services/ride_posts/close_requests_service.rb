# frozen_string_literal: true

module RidePosts
  class CloseRequestsService
    class Error < StandardError; end

    def self.call(ride_post, actor:)
      ride_post.with_lock do
        raise Error, "Only the driver can close seat requests" unless ride_post.user_id == actor.id
        return ride_post if ride_post.requests_closed_at.present?
        raise Error, "Only upcoming published trips can close seat requests" unless ride_post.published? && ride_post.booking_cutoff_at&.future?

        ride_post.update!(requests_closed_at: Time.current)
        Bookings::ExpireService.call(ride_post)
        ride_post
      end
    end
  end
end
