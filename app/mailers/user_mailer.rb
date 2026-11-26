class UserMailer < ApplicationMailer
  COMMUNITY_SURVEY_URL = "https://docs.google.com/forms/d/e/1FAIpQLScCxjDpIGTzJe6KZ3cFCMwgkqDwWIghUgNAwt1dSiia-7dpGQ/viewform".freeze
  FACEBOOK_PAGE_URL = "https://www.facebook.com/people/Pasabayaapp-Carpooling-for-the-Community/61589209230043/".freeze

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

  def community_survey
    @user = params[:user_id] ? User.find_by(id: params[:user_id]) : params[:user]
    return if @user.nil? || @user.deleted? || @user.banned_at.present?

    @survey_url = params[:survey_url] || COMMUNITY_SURVEY_URL
    @facebook_url = FACEBOOK_PAGE_URL

    mail(to: @user.email_address, subject: "Help shape what we build next for Pasabaya (10-min survey)")
  end
end
