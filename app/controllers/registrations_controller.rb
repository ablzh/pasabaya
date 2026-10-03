class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  before_action :redirect_if_authenticated, only: %i[ new create ]

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)
    if @user.save
      # Log the user in immediately after creating their account
      unless start_new_session_for @user
        redirect_to new_session_path, alert: "This account has been deleted.", status: :see_other
        return
      end
      UserMailer.welcome(@user).deliver_later
      redirect_to root_path, notice: "Welcome to Pasabaya! Your account was successfully created.", status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def redirect_if_authenticated
    if authenticated?
      redirect_to root_path, alert: "You are already signed in.", status: :see_other
    end
  end

  def registration_params
    params.expect(user: [ :first_name, :last_name, :facebook_profile_url, :email_address, :password, :password_confirmation ])
  end
end
