class Settings::EmailsController < Settings::BaseController
  def update
    @user = Current.user
    if @user.update(email_params)
      UserMailer.with(user: @user).email_confirmation.deliver_later
      redirect_to settings_profile_path, notice: "Confirmation link sent to #{@user.unconfirmed_email}."
    else
      render "settings/profiles/show", status: :unprocessable_content
    end
  end

  private

  def email_params
    params.expect(user: [ :password_challenge, :unconfirmed_email ]).with_defaults(password_challenge: "")
  end
end
