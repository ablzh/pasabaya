class ChatsController < ApplicationController
  def index
    user = Current.user
    @rides = user.authorized_chat_rides(includes: [ :origin, :destination, :bookings ])
    @latest_messages = ChatMessage.latest_for_rides(@rides.map(&:id))
                                 .index_by(&:ride_post_id)
    @unread_ride_ids = user.unread_chat_ride_ids(rides: @rides)
    @rides.sort_by! { |ride| [ @latest_messages[ride.id]&.created_at || ride.created_at, ride.id ] }.reverse!
  end
end
