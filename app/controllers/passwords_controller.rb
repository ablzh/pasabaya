class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]
  rate_limit to: 10, within: 3.minutes, name: "ip", only: :create, with: -> { redirect_to new_password_path, alert: "Try again later.", status: :see_other }
  rate_limit to: 1, within: 1.minute, name: "recipient-minute", only: :create,
    by: -> { email_rate_limit_key(params[:email_address]) }, with: :reset_instructions_sent
  rate_limit to: 5, within: 1.hour, name: "recipient-hour", only: :create,
    by: -> { email_rate_limit_key(params[:email_address]) }, with: :reset_instructions_sent

  def new
  end

  def create
    if user = User.find_by(email_address: params[:email_address])
      PasswordsMailer.reset(user).deliver_later
    end

    reset_instructions_sent
  end

  def edit
  end

  def update
    if @user.update(params.permit(:password, :password_confirmation))
      @user.sessions.destroy_all
      redirect_to new_session_path, notice: "Password has been reset.", status: :see_other
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  private
    def reset_instructions_sent
      redirect_to new_session_path, notice: "Password reset instructions sent (if user with that email address exists).", status: :see_other
    end

    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_password_path, alert: "Password reset link is invalid or has expired.", status: :see_other
    end
end
