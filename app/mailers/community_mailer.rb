class CommunityMailer < ApplicationMailer
  def verification_email(membership)
    @membership = membership
    @user = membership.user
    @community = membership.community
    @token = @membership.generate_token_for(:verification)

    mail(
      to: @membership.institutional_email,
      subject: "Verify your #{@community.name} community email on Pasabaya"
    )
  end
end
