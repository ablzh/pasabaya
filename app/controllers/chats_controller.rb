class ChatsController < ApplicationController
  def index
    user = Current.user
    @rides = user.authorized_chat_rides(includes: [ :origin, :destination, :bookings ])
    @latest_messages = ChatMessage.where(ride_post_id: @rides.map(&:id))
                                 .where("chat_messages.id = (SELECT latest.id FROM chat_messages latest WHERE latest.ride_post_id = chat_messages.ride_post_id ORDER BY latest.created_at DESC, latest.id DESC LIMIT 1)")
                                 .index_by(&:ride_post_id)
    @read_states = user.chat_read_states.where(ride_post_id: @rides.map(&:id)).index_by(&:ride_post_id)
    @rides.sort_by! { |ride| [ @latest_messages[ride.id]&.created_at || ride.created_at, ride.id ] }.reverse!
  end
end
