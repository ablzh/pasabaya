class CommunityMembershipsController < ApplicationController
  allow_unauthenticated_access only: [ :verify ]
  before_action :resume_session, only: [ :verify ]
  before_action :require_authentication, except: [ :verify ]

  def create
    @community = Community.find_by(slug: params[:community_id]) || Community.find(params[:community_id])
    institutional_email = params[:institutional_email].to_s.strip.downcase

    @membership = Current.user.community_memberships.find_or_initialize_by(community: @community)
    @membership.institutional_email = institutional_email
    @membership.verified_at = nil
    @membership.revoked_at = nil

    if @membership.save
      CommunityMailer.verification_email(@membership).deliver_later
      redirect_to @community, notice: "Verification email sent to #{institutional_email}. Please check your inbox within 24 hours to confirm.", status: :see_other
    else
      redirect_to @community, alert: @membership.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def destroy
    @community = Community.find_by(slug: params[:community_id]) || Community.find(params[:community_id])
    @membership = Current.user.community_memberships.find_by!(community: @community)
    @membership.revoke!

    redirect_to @community, notice: "You have left the #{@community.name} community. Any upcoming community rides or bookings have been canceled.", status: :see_other
  end

  def verify
    membership = CommunityMembership.find_by_token_for(:verification, params[:token])

    if membership.nil?
      redirect_to root_path, alert: "The verification link is invalid or has expired."
      return
    end

    if authenticated? && Current.user.id != membership.user_id
      redirect_to root_path, alert: "This verification link belongs to a different account."
      return
    end

    if CommunityMembership.active_verified.where(institutional_email: membership.institutional_email).where.not(id: membership.id).exists?
      redirect_to root_path, alert: "This institutional email address is already verified by another account."
      return
    end

    membership.verify!
    target = authenticated? ? community_path(membership.community) : new_session_path
    redirect_to target, notice: "Your email has been verified! Welcome to #{membership.community.name}."
  end
end
