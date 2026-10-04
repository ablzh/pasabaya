class CommunitiesController < ApplicationController
  allow_unauthenticated_access only: [ :index, :show ]
  before_action :resume_session

  def index
    @communities = Community.order(:name)
    @my_memberships = authenticated? ? Current.user.community_memberships.index_by(&:community_id) : {}
    @member_counts = CommunityMembership.active_verified.group(:community_id).count
  end

  def show
    if params[:id] == "up-diliman"
      up_community = Community.find_by(domain: "up.edu.ph")
      return redirect_to community_path(up_community), status: :moved_permanently if up_community
    end

    @community = Community.find_by(slug: params[:id]) || Community.find(params[:id])
    @membership = authenticated? ? Current.user.community_memberships.find_by(community: @community) : nil
    @ride_posts = @community.ride_posts.active.upcoming.visible_to(Current.user).includes(:origin, :destination, :user).order(departure_date: :asc, departure_time: :asc)
  end
end
