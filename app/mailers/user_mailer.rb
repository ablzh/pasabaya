class UserMailer < ApplicationMailer
  default from: "hello@yourproject.com" # Твой будущий адрес

  def welcome_email(subscriber)
    @subscriber = subscriber
    mail(to: @subscriber.email, subject: "Welcome to Pasabaya.app! Let’s face the energy crisis together 🚗")
  end
end
