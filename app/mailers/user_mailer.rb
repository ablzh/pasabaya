class UserMailer < ApplicationMailer
  def welcome(user)
    @user = user
    mail(to: @user.email_address, subject: "Welcome to Pasabaya.app! Let's beat the traffic together 🚗")
  end
end
