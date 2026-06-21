class Settings::PasswordsController < Settings::BaseController
  def update
    @user = Current.user
    if @user.update(password_params)
      @user.sessions.where.not(id: Current.session.id).destroy_all
      redirect_to settings_profile_path, notice: "Password changed successfully."
    else
      render "settings/profiles/show", status: :unprocessable_content
    end
  end

  private

  def password_params
    params.expect(user: [ :password_challenge, :password, :password_confirmation ]).with_defaults(password_challenge: "")
  end
end