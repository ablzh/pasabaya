class UserMailer < ApplicationMailer
  def welcome(user)
    @user = user
    mail(to: @user.email_address, subject: "Welcome to Pasabaya.app! Let's beat the traffic together")
  end

  def email_confirmation
    @user = params[:user]
    @token = @user.generate_token_for(:email_confirmation)

    mail(
      to: @user.unconfirmed_email,
      subject: "Confirm your new email address"
    )
  end

  def ride_upgrade
    @user = User.find_by(id: params.fetch(:user_id))
    return if @user.nil? || @user.deleted? || @user.banned_at.present?

    @schedules = @user.ride_schedules.where(id: params.fetch(:schedule_ids, [])).includes(:origin, :destination).order(:id).to_a
    @rides = @user.ride_posts.where(id: params.fetch(:ride_ids, [])).includes(:origin, :destination).order(:id).to_a
    return if @schedules.empty? && @rides.empty?

    @review_heading = @schedules.any? ? "Please review your regular rides" : "Please review your rides"
    mail(to: @user.email_address, subject: "Pasabaya has new features — #{@review_heading.downcase}")
  end

  def platform_update
    @user = User.find_by(id: params.fetch(:user_id))
    return if @user.nil? || @user.deleted? || @user.banned_at.present?

    mail(to: @user.email_address, subject: "Pasabaya has been updated — find or offer your next ride")
  end
end
