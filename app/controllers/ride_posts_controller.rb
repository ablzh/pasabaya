class RidePostsController < ApplicationController
  before_action :require_authentication, except: %i[ index show ]
  before_action :set_ride_post, only: :show
  before_action :set_user_ride_post, only: %i[ edit update destroy cancel ]
  before_action :resume_session, only: [ :index, :show ]
  before_action :set_grouped_locations, only: %i[ index new edit create update ]
  before_action :resolve_route_slugs, only: :index
  before_action :redirect_to_seo_route, only: :index


  # GET /ride_posts or /ride_posts.json
  def index
    if params.key?(:origin_id) || params.key?(:destination_id) || params.key?(:community_id) || params.key?(:ladies_only) || params.key?(:departure_date)
      @ride_posts = RidePost.active.upcoming
                            .visible_to(Current.user)
                            .includes(:origin, :destination, :community, user: { avatar_attachment: :blob })
                            .order(departure_time: :asc)
                            .filter_by_origin(params[:origin_id])
                            .filter_by_destination(params[:destination_id])
                            .filter_by_community(params[:community_id])
                            .filter_by_ladies_only(params[:ladies_only])
                            .filter_by_departure_date(params[:departure_date])

      setup_route_meta_tags if @origin && @destination
    else
      @ride_posts = RidePost.none
      @popular_routes = RidePost.popular_routes
    end
  end

  # GET /ride_posts/1 or /ride_posts/1.json
  def show
    unless @ride_post.authorized_viewer?(Current.user)
      respond_to do |format|
        format.html { redirect_to ride_posts_path, alert: "You are not authorized to view this restricted ride." }
        format.json { render json: { error: "Forbidden" }, status: :forbidden }
      end
      return
    end

    if params[:id] != @ride_post.to_param
      redirect_to ride_post_path(@ride_post, tab: params[:tab].presence, format: params[:format]), status: :moved_permanently
      return # Use return to stop execution after redirecting
    end

    setup_show_meta_tags
    @chat_messages = @ride_post.chat_messages.includes(user: { avatar_attachment: :blob }).order(created_at: :desc, id: :desc).limit(100).to_a.reverse if @ride_post.user_authorized_for_chat?(Current.user)
  end

  # GET /ride_posts/new
  def new
    @ride_post = Current.user.ride_posts.build
    if params[:community_id].present?
      @ride_post.community = Current.user.verified_communities.find(params[:community_id])
      @ride_post.visibility = :hub_only
    end
  end

  # GET /ride_posts/1/edit
  def edit
  end

  # POST /ride_posts or /ride_posts.json
  def create
    @ride_post = Current.user.ride_posts.build(ride_post_params)
    if @ride_post.offering?
      @ride_post.remaining_seats ||= @ride_post.seats
      if @ride_post.departure_time.blank? || @ride_post.expected_arrival_at.blank?
        @ride_post.status = :draft
      end
    end

    respond_to do |format|
      if @ride_post.save
        notice = @ride_post.draft? ? "Ride offer saved as a private draft. Add departure and arrival times to publish it." : "Ride post was successfully created."
        format.html { redirect_to @ride_post, notice: notice, status: :see_other }
        format.json { render :show, status: :created, location: @ride_post }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @ride_post.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /ride_posts/1 or /ride_posts/1.json
  def update
    @ride_post.assign_attributes(ride_post_params)
    if @ride_post.offering? && @ride_post.draft? && @ride_post.departure_time.present? && @ride_post.expected_arrival_at.present?
      @ride_post.status = :active
      @ride_post.remaining_seats ||= @ride_post.seats
    end

    respond_to do |format|
      if @ride_post.save
        format.html { redirect_to @ride_post, notice: "Ride post was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @ride_post }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @ride_post.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /ride_posts/1 or /ride_posts/1.json
  def destroy
    if @ride_post.destroy
      respond_to do |format|
        format.html { redirect_to ride_posts_path, notice: "Ride post was successfully destroyed.", status: :see_other }
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.html { redirect_to @ride_post, alert: @ride_post.errors.full_messages.to_sentence, status: :see_other }
        format.json { render json: @ride_post.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH /rides/1/cancel
  def cancel
    RidePosts::CancelService.call(@ride_post, actor: Current.user)
    respond_to do |format|
      format.html { redirect_to @ride_post, notice: "Trip was successfully canceled.", status: :see_other }
      format.json { head :no_content }
    end
  rescue RidePosts::CancelService::Error => e
    respond_to do |format|
      format.html { redirect_to @ride_post, alert: e.message, status: :see_other }
      format.json { render json: { error: e.message }, status: :unprocessable_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_ride_post
    @ride_post = RidePost.includes(:origin, :destination, :community).find(params.expect(:id))
  end

  def set_user_ride_post
    @ride_post = Current.user.ride_posts.includes(:origin, :destination).find(params.expect(:id))
  end

  # Only allow a list of trusted parameters through.
  def ride_post_params
    params.expect(ride_post: [
      :origin_id, :destination_id, :departure_time, :expected_arrival_at,
      :seats, :notes,
      :ladies_only, :visibility, :community_id
    ])
  end

  def set_grouped_locations
    @grouped_locations = Location.grouped_by_region
  end

  def resolve_route_slugs
    if params[:origin_slug].present? && params[:destination_slug].present?
      @origin = Location.find_by_slug(params[:origin_slug])
      @destination = Location.find_by_slug(params[:destination_slug])

      if @origin && @destination
        params[:origin_id] = @origin.id
        params[:destination_id] = @destination.id
      else
        redirect_to ride_posts_path, alert: "Route not found"
      end
    end
  end

  def setup_route_meta_tags
    route_url = route_rides_url(origin_slug: @origin.slug, destination_slug: @destination.slug)
    set_meta_tags(
      title: "Carpool from #{@origin.name} to #{@destination.name}",
      description: "Find rides and carpools from #{@origin.name} to #{@destination.name} on Pasabaya.app. Share fuel costs and travel together.",
      canonical: route_url,
      og: {
        title: "Carpool from #{@origin.name} to #{@destination.name} | Pasabaya",
        description: "Find travel companions from #{@origin.name} to #{@destination.name}. No booking fees.",
        url: route_url
      }
    )
  end

  def setup_show_meta_tags
    formatted_time = if @ride_post.regular?
                       "Flexible departure"
    else
                       @ride_post.departure_time.strftime("%A, %b %d at %I:%M %p")
    end

    title_text = "Ride from #{@ride_post.origin.name} to #{@ride_post.destination.name}"
    desc_text = "#{@ride_post.user.first_name} is #{@ride_post.post_type} a ride. " \
      "Departure: #{formatted_time}. " \
      "Total seats: #{@ride_post.seats}. " \
      "View profiles before traveling. Seat requests need driver approval; accepted participants coordinate in private in-app chat."

    canonical_url = ride_post_url(@ride_post)
    set_meta_tags(
      title: title_text,
      description: desc_text,
      canonical: canonical_url,
      noindex: true,
      og: {
        title: "#{title_text} | Pasabaya",
        description: desc_text,
        type: "article",
        url: canonical_url
      }
    )
  end

  def redirect_to_seo_route
    if params[:origin_id].present? && params[:destination_id].present? && params[:origin_slug].blank? && request.format.html?
      locations = Location.where(id: [ params[:origin_id], params[:destination_id] ]).index_by(&:id)
      origin = locations[params[:origin_id].to_i]
      destination = locations[params[:destination_id].to_i]

      if origin && destination
        redirect_to route_rides_path(
                      origin_slug: origin.slug,
                      destination_slug: destination.slug,
                      departure_date: params[:departure_date].presence,
                      community_id: params[:community_id].presence,
                      ladies_only: params[:ladies_only].presence
                    )
      end
    end
  end
end
