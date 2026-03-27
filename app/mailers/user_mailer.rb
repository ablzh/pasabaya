class UserMailer < ApplicationMailer
  def welcome_email(subscriber)
    @subscriber = subscriber
    token = @subscriber.signed_id(purpose: :unsubscribe)
    url = unsubscribe_subscriber_url(token)
    headers["List-Unsubscribe"] = "<#{url}>"
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
    mail(to: @subscriber.email, subject: "Welcome to Pasabaya.app! Let’s face the energy crisis together 🚗")
  end
end
