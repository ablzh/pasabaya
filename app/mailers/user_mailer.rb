class UserMailer < ApplicationMailer
  default from: 'hello@yourproject.com' # Твой будущий адрес

  def welcome_email(subscriber)
    @subscriber = subscriber
    mail(to: @subscriber.email, subject: 'Thanks for subscribing!')
  end
end