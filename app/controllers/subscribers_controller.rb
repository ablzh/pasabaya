# frozen_string_literal: true

class SubscribersController < ApplicationController
  def create
    @subscriber = Subscriber.new(subscriber_params)
    if @subscriber.save
      redirect_to root_path, notice: "Thanks for subscribing!"
    else
      redirect_to root_path, alert: "Error in email or name."
    end
  end

  private

  def subscriber_params
    params.require(:subscriber).permit(:name, :email)
  end
end