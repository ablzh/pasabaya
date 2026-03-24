# frozen_string_literal: true

class SubscribersController < ApplicationController
  def create
    @subscriber = Subscriber.new(subscriber_params)
    if @subscriber.save
      # Отправляем письмо! .deliver_later делает это асинхронно
      UserMailer.welcome_email(@subscriber).deliver_later

      redirect_to root_path, notice: "Вы успешно подписаны! Письмо уже в пути (проверьте Mailtrap)."
    else
      # Если валидация не прошла, нам нужно передать ошибки обратно на главную
      render "pages/home", status: :unprocessable_entity
    end
  end

  private

  def subscriber_params
    params.require(:subscriber).permit(:name, :email)
  end
end