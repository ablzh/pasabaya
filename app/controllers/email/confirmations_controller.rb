class Email::ConfirmationsController < ApplicationController
  allow_unauthenticated_access

  def show
    if (user = User.find_by_token_for(:email_confirmation, params[:token]))
      if user.deleted?
        redirect_to root_path, alert: "This account has been deleted."
        return
      end

      unless user.confirm_email
        redirect_to root_path, alert: "The confirmation link is invalid or has expired. Request a new email confirmation in Account Settings."
        return
      end

      target_path = authenticated? ? settings_profile_path : new_session_path
      redirect_to target_path, notice: "Email address confirmed!"
    else
      redirect_to root_path, alert: "The confirmation link is invalid or has expired. Request a new email confirmation in Account Settings."
    end
  end
end
