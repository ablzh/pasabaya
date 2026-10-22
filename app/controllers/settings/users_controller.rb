class Settings::UsersController < Settings::BaseController
  def destroy
    @user = Current.user

    if @user.authenticate(params[:password_challenge])
      if Users::AnonymizeService.call(@user)
        terminate_session
        redirect_to root_path, notice: "Your account has been deleted.", status: :see_other
      else
        redirect_to settings_profile_path, alert: "Account could not be deleted at this time. Please contact privacy@pasabaya.app.", status: :see_other
      end
    else
      @user.errors.add(:password_challenge, :invalid)
      render "settings/profiles/show", status: :unprocessable_content
    end
  end
end
