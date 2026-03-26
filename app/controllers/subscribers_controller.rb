# frozen_string_literal: true

class SubscribersController < ApplicationController

  invisible_captcha only: [:create],
                    honeypot: :nickname,
                    timestamp_enabled: true,
                    timestamp_threshold: 4

  def create
    @subscriber = Subscriber.new(subscriber_params)
    if @subscriber.save
      # Отправляем письмо! .deliver_later делает это асинхронно
      UserMailer.welcome_email(@subscriber).deliver_later

      redirect_to root_path, notice: "You've successfully subscribed for updates! The email is on its way."
    else
      render "pages/home", status: :unprocessable_entity
    end
  end

  private

  def subscriber_params
    params.require(:subscriber).permit(:name, :email)
  end
end
