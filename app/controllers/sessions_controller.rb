class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later.", status: :see_other }
  before_action :redirect_if_authenticated, only: %i[ new create ]

  def new
    return_path = params[:return_to]
    if return_path.present? && return_path.start_with?("/") && !return_path.start_with?("//") && !return_path.match?(/[\\\x00-\x1f]/)
      session[:return_to_after_authenticating] = params[:return_to]
    end
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      redirect_to after_authentication_url, status: :see_other
    else
      flash.now[:alert] = "Try another email address or password."
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end

  private

  def redirect_if_authenticated
    if authenticated?
      redirect_to root_path, alert: "You are already signed in.", status: :see_other
    end
  end
end
