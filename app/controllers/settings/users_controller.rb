class Settings::UsersController < Settings::BaseController
  def destroy
    @user = Current.user

    if @user.authenticate(params[:password_challenge])
      Subscriber.find_by(email: @user.email_address)&.destroy
      terminate_session
      @user.destroy!

      redirect_to root_path, notice: "Your account has been deleted.", status: :see_other
    else
      redirect_to settings_profile_path, alert: "Incorrect password. Account was not deleted."
    end
  end
end
