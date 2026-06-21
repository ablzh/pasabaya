class Settings::ProfilesController < Settings::BaseController
  def show
    @user = Current.user
  end

  def update
    @user = Current.user
    if @user.update(profile_params)
      redirect_to settings_profile_path, notice: "Profile updated successfully."
    else
      render :show, status: :unprocessable_content
    end
  end

  private

  def profile_params
    params.expect(user: [ :first_name, :last_name, :facebook_profile_url, :avatar ])
  end
end
