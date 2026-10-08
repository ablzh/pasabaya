# frozen_string_literal: true

class SubscribersController < ApplicationController
  allow_unauthenticated_access only: :unsubscribe

  def unsubscribe
    @subscriber = Subscriber.find_signed(params[:id], purpose: :unsubscribe)
    if @subscriber
      @subscriber.update!(unsubscribed_at: Time.current) unless @subscriber.unsubscribed_at?
      render :unsubscribe_success
    else
      render plain: "Invalid unsubscribe link", status: :not_found
    end
  end
end
