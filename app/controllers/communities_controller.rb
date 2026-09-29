class CommunitiesController < ApplicationController
  allow_unauthenticated_access only: [ :index, :show ]
  before_action :resume_session

  def index
    @communities = Community.order(:name)
    @my_memberships = authenticated? ? Current.user.community_memberships.index_by(&:community_id) : {}
    @member_counts = CommunityMembership.active_verified.group(:community_id).count
  end

  def show
    @community = Community.find_by(slug: params[:id]) || Community.find(params[:id])
    @membership = authenticated? ? Current.user.community_memberships.find_by(community: @community) : nil
    @ride_posts = @community.ride_posts.active.visible_to(Current.user).includes(:origin, :destination, :user).order(departure_time: :asc)
  end
end
