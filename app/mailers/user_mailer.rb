class UserMailer < ApplicationMailer
  def welcome(user)
    @user = user
    mail(to: @user.email_address, subject: "Welcome to Pasabaya.app! Let's beat the traffic together 🚗")
  end

  def email_confirmation
    @user = params[:user]
    @token = @user.generate_token_for(:email_confirmation)

    mail(
      to: @user.unconfirmed_email,
      subject: "Confirm your new email address"
    )
  end

end
