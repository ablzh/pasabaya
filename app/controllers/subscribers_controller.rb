# frozen_string_literal: true

class SubscribersController < ApplicationController

  invisible_captcha only: [:create],
                    honeypot: :nickname,
                    timestamp_enabled: true,
                    timestamp_threshold: 4

  def create
    @subscriber = Subscriber.new(subscriber_params)
    if @subscriber.save
      UserMailer.welcome_email(@subscriber).deliver_later
      flash.now[:notice] = "You've successfully subscribed for updates! The email is on its way."

      respond_to do |format|
        format.turbo_stream
        format.html {redirect_to root_path, notice: flash[:notice]}
      end
    else
      render "pages/home", status: :unprocessable_entity
    end
  end

  private

  def subscriber_params
    params.require(:subscriber).permit(:name, :email)
  end
end
