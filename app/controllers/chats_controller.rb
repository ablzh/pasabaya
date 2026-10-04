class ChatsController < ApplicationController
  def index
    user = Current.user
    verified_ids = user.verified_community_ids
    candidate_bookings = user.bookings.where("status = ? OR (status = ? AND accepted_at IS NOT NULL)", Booking.statuses[:accepted], Booking.statuses[:canceled])
    candidates = RidePost.where(user: user).or(RidePost.where(id: candidate_bookings.select(:ride_post_id)))
                         .includes(:origin, :destination, :bookings)
    @rides = candidates.select { |ride| ride.user_authorized_for_chat?(user, verified_community_ids: verified_ids) }
    @latest_messages = ChatMessage.where(ride_post_id: @rides.map(&:id))
                                 .where("chat_messages.id = (SELECT latest.id FROM chat_messages latest WHERE latest.ride_post_id = chat_messages.ride_post_id ORDER BY latest.created_at DESC, latest.id DESC LIMIT 1)")
                                 .index_by(&:ride_post_id)
    @rides.sort_by! { |ride| [ @latest_messages[ride.id]&.created_at || ride.created_at, ride.id ] }.reverse!
  end
end
