class Settings::EmailsController < Settings::BaseController
  rate_limit to: 5, within: 10.minutes, name: "account", only: :update,
    by: -> { Current.user.id }, with: :reject_rate_limited_request
  rate_limit to: 1, within: 1.minute, name: "recipient-minute", only: :update,
    by: -> { email_rate_limit_key(email_params[:unconfirmed_email]) }, with: :reject_rate_limited_request
  rate_limit to: 5, within: 1.hour, name: "recipient-hour", only: :update,
    by: -> { email_rate_limit_key(email_params[:unconfirmed_email]) }, with: :reject_rate_limited_request

  def update
    @user = Current.user
    @user.assign_attributes(email_params)
    if @user.save(context: :email_change)
      UserMailer.with(user: @user).email_confirmation.deliver_later
      redirect_to settings_profile_path, notice: "Confirmation link sent to #{@user.unconfirmed_email}.", status: :see_other
    else
      render "settings/profiles/show", status: :unprocessable_content
    end
  end

  private

  def email_params
    params.expect(user: [ :password_challenge, :unconfirmed_email ]).with_defaults(password_challenge: "")
  end
end
