class RidePostsController < ApplicationController
  before_action :require_authentication, except: %i[ index show ]
  before_action :set_ride_post, only: %i[ show edit update destroy ]
  before_action :resume_session, only: [ :index, :show ]
  before_action :set_grouped_locations, only: %i[ index new edit create update ]
  before_action :resolve_route_slugs, only: :index
  before_action :redirect_to_seo_route, only: :index


  # GET /ride_posts or /ride_posts.json
  def index
    if params.key?(:post_type) || params.key?(:origin_id) || params.key?(:destination_id)
      @ride_posts = RidePost.active
                            .includes(:origin, :destination, :user)
                            .order(departure_time: :asc)
                            .filter_by_post_type(params[:post_type])
                            .filter_by_origin(params[:origin_id])
                            .filter_by_destination(params[:destination_id])

      setup_route_meta_tags if @origin && @destination
    else
      @ride_posts = RidePost.none
      @popular_routes = RidePost.popular_routes
    end
  end

  # GET /ride_posts/1 or /ride_posts/1.json
  def show
    if params[:id] != @ride_post.to_param
      redirect_to @ride_post, status: :moved_permanently
      return # Use return to stop execution after redirecting
    end

    setup_show_meta_tags
  end

  # GET /ride_posts/new
  def new
    @ride_post = RidePost.new
  end

  # GET /ride_posts/1/edit
  def edit
  end

  # POST /ride_posts or /ride_posts.json
  def create
    @ride_post = Current.user.ride_posts.build(ride_post_params)

    respond_to do |format|
      if @ride_post.save
        format.html { redirect_to @ride_post, notice: "Ride post was successfully created." }
        format.json { render :show, status: :created, location: @ride_post }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @ride_post.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /ride_posts/1 or /ride_posts/1.json
  def update
    respond_to do |format|
      if @ride_post.update(ride_post_params)
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
    @ride_post.destroy!

    respond_to do |format|
      format.html { redirect_to ride_posts_path, notice: "Ride post was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_ride_post
    @ride_post = RidePost.find(params.expect(:id))
  end

  # Only allow a list of trusted parameters through.
  def ride_post_params
    params.expect(ride_post: [ :post_type, :origin_id, :destination_id, :departure_time, :seats, :notes ])
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
    set_meta_tags(
      title: "Carpool from #{@origin.name} to #{@destination.name}",
      description: "Find rides and carpools from #{@origin.name} to #{@destination.name} on Pasabaya.app. Share fuel costs and travel together.",
      og: {
        title: "Carpool from #{@origin.name} to #{@destination.name} | Pasabaya",
        description: "Find travel companions from #{@origin.name} to #{@destination.name}. No booking fees."
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
      "Seats available: #{@ride_post.seats}. " \
      "Check notes and coordinate via Facebook."

    set_meta_tags(
      title: title_text,
      description: desc_text,
      og: {
        title: "#{title_text} | Pasabaya",
        description: desc_text,
        type: "article"
      }
    )
  end

  def redirect_to_seo_route
    if params[:origin_id].present? && params[:destination_id].present? && params[:origin_slug].blank? && request.format.html?
      origin = Location.find_by(id: params[:origin_id])
      destination = Location.find_by(id: params[:destination_id])

      if origin && destination
        redirect_to route_rides_path(
                      origin_slug: origin.slug,
                      destination_slug: destination.slug,
                      post_type: params[:post_type].presence
                    )
      end
    end
  end
end
