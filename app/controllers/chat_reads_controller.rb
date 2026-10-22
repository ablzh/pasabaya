# frozen_string_literal: true

class ChatReadsController < ApplicationController
  before_action :set_ride_post

  def create
    unless @ride_post.user_authorized_for_chat?(Current.user)
      return head :forbidden
    end

    last_message_id = params[:last_message_id].presence
    if last_message_id
      return head :unprocessable_content unless last_message_id.to_s.match?(/\A[1-9]\d*\z/)
      return head :unprocessable_content unless @ride_post.chat_messages.exists?(id: last_message_id)

      ChatReadState.mark_read!(user: Current.user, ride_post: @ride_post, message_id: last_message_id)
    end
    head :ok
  end

  private

  def set_ride_post
    @ride_post = RidePost.find(params[:ride_post_id])
  end
end
