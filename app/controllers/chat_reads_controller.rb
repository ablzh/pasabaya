# frozen_string_literal: true

class ChatReadsController < ApplicationController
  before_action :set_ride_post

  def create
    unless @ride_post.user_authorized_for_chat?(Current.user)
      return head :forbidden
    end

    last_message_id = params[:last_message_id].presence
    if last_message_id
      ChatReadState.mark_read!(user: Current.user, ride_post: @ride_post, message_id: last_message_id)
    end
    head :ok
  end

  private

  def set_ride_post
    @ride_post = RidePost.find(params[:ride_post_id])
  end
end
