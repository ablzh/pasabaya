# frozen_string_literal: true

class ChatMessagesController < ApplicationController
  before_action :require_authentication
  before_action :set_ride_post
  before_action :authorize_participant
  rate_limit to: 30, within: 1.minute, name: "account", only: :create,
    by: -> { Current.user.id }, with: :reject_rate_limited_request

  # POST /rides/:ride_post_id/chat_messages
  def create
    @chat_message = @ride_post.chat_messages.build(chat_message_params.merge(user: Current.user))

    respond_to do |format|
      if @chat_message.save
        format.turbo_stream
        format.html { redirect_to ride_post_path(@ride_post, tab: "chat"), notice: "Message sent.", status: :see_other }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "chat_message_form",
            partial: "chat_messages/form",
            locals: { ride_post: @ride_post, chat_message: @chat_message }
          ), status: :unprocessable_content
        end
        format.html { redirect_to ride_post_path(@ride_post, tab: "chat"), alert: model_error_feedback(@chat_message, title: "Your message wasn’t sent. Check the message and try again."), status: :see_other }
      end
    end
  end

  private

  def set_ride_post
    @ride_post = RidePost.find(params[:ride_post_id])
  end

  def authorize_participant
    unless @ride_post.user_authorized_for_chat?(Current.user)
      alert_text = @ride_post.chat_expired? ? "Chat history for this trip is no longer available." : "Only the driver and confirmed passengers can access trip chat."
      redirect_to @ride_post, alert: alert_text
    end
  end

  def chat_message_params
    params.expect(chat_message: [ :body ])
  end
end
