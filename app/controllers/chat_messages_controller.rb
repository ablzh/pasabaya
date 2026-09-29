# frozen_string_literal: true

class ChatMessagesController < ApplicationController
  before_action :require_authentication
  before_action :set_ride_post
  before_action :authorize_participant

  # POST /rides/:ride_post_id/chat_messages
  def create
    @chat_message = @ride_post.chat_messages.build(chat_message_params.merge(user: Current.user))

    respond_to do |format|
      if @chat_message.save
        format.turbo_stream
        format.html { redirect_to @ride_post, notice: "Message sent." }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "chat_message_form",
            partial: "chat_messages/form",
            locals: { ride_post: @ride_post, chat_message: @chat_message }
          ), status: :unprocessable_content
        end
        format.html { redirect_to @ride_post, alert: @chat_message.errors.full_messages.to_sentence }
      end
    end
  end

  private

  def set_ride_post
    @ride_post = RidePost.find(params[:ride_post_id])
  end

  def authorize_participant
    unless @ride_post.user_authorized_for_chat?(Current.user)
      redirect_to @ride_post, alert: "Only the driver and confirmed passengers can access trip chat."
    end
  end

  def chat_message_params
    params.expect(chat_message: [ :body ])
  end
end
