class Email::ConfirmationsController < ApplicationController
  allow_unauthenticated_access

  def show
    if (user = User.find_by_token_for(:email_confirmation, params[:token]))
      user.confirm_email

      target_path = authenticated? ? settings_profile_path : new_session_path
      redirect_to target_path, notice: "Email address confirmed!"
    else
      redirect_to root_path, alert: "The confirmation link is invalid or has expired."
    end
  end
end