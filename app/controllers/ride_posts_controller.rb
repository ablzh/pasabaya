class RidePostsController < ApplicationController
  prepend_before_action :require_html_response
  before_action :require_authentication, except: %i[ index show ]
  before_action :set_ride_post, only: :show
  before_action :set_user_ride_post, only: %i[ edit update destroy cancel publish close_requests reopen_requests ]
  before_action :resume_session, only: [ :index, :show ]
  before_action :set_grouped_locations, only: %i[ index new edit create update ]
  before_action :resolve_route_slugs, only: :index
  before_action :resolve_search_locations, only: :index
  before_action :redirect_to_seo_route, only: :index
  rate_limit to: 10, within: 10.minutes, name: "account", only: :create,
    by: -> { Current.user.id }, with: :reject_rate_limited_request


  # GET /rides
  def index
    if params.key?(:origin_id) || params.key?(:destination_id) || params.key?(:community_id) || params.key?(:ladies_only) || params.key?(:departure_date) || params[:q].present? || params[:query].present? || params[:origin].present? || params[:destination].present?
      @ride_posts = RidePost.accepting_requests
                            .visible_to(Current.user)
                            .includes(:origin, :destination, :community, :ride_schedule, user: { avatar_attachment: :blob })
                            .order(departure_date: :asc, departure_time: :asc)
                            .filter_by_origin(params[:origin_id])
                            .filter_by_destination(params[:destination_id])
                            .filter_by_community(params[:community_id])
                            .filter_by_ladies_only(params[:ladies_only])
                            .filter_by_departure_date(params[:departure_date])
      @ride_posts = @ride_posts.none if @unresolved_location_search
      @ride_posts = @ride_posts.one_per_schedule if params[:departure_date].blank?

      if @origin && @destination
        setup_route_meta_tags
        if authenticated?
          @existing_route_subscription = Current.user.route_subscriptions.active.find_by(
            origin_id: @origin.id,
            destination_id: @destination.id,
            departure_date: params[:departure_date].presence,
            community_id: params[:community_id].presence,
            ladies_only: ActiveModel::Type::Boolean.new.cast(params[:ladies_only]) || false
          )
        end
      end
      @popular_routes = RidePost.popular_routes if @ride_posts.none?
    else
      @ride_posts = RidePost.none
      @popular_routes = RidePost.popular_routes
    end
  end

  # GET /rides/:id
  def show
    unless @ride_post.authorized_viewer?(Current.user)
      redirect_to ride_posts_path, alert: "You are not authorized to view this restricted ride."
      return
    end

    if params[:id] != @ride_post.to_param
      redirect_to ride_post_path(@ride_post, tab: params[:tab].presence), status: :moved_permanently
      return
    end

    if params[:tab] == "chat" && @ride_post.chat_expired?
      redirect_to ride_post_path(@ride_post), alert: "Chat history for this trip is no longer available."
      return
    end

    if @ride_post.booking_cutoff_at.present? && Time.current >= @ride_post.booking_cutoff_at && @ride_post.bookings.pending.exists?
      Bookings::ExpireService.call(@ride_post)
    end

    setup_show_meta_tags
    load_trip_panels
  end

  # GET /rides/new
  def new
    if params[:ride_type] == "regular"
      @ride_schedule = Current.user.ride_schedules.build
      if params[:source_ride_post_id].present?
        source = Current.user.ride_posts.find(params[:source_ride_post_id])
        @ride_schedule.assign_attributes(source.attributes.slice(*RideSchedule::OFFER_FIELDS))
        @ride_schedule.source_ride_post = source
      end
    else
      @ride_post = Current.user.ride_posts.build
    end
    if params[:community_id].present?
      offer = @ride_schedule || @ride_post
      offer.community = Current.user.verified_communities.find(params[:community_id])
      offer.visibility = :hub_only
    end
  end

  # GET /rides/:id/edit
  def edit
  end

  # POST /rides
  def create
    return create_regular_ride if params[:ride_type] == "regular"

    @ride_post = Current.user.ride_posts.build(ride_post_params)
    @ride_post.status = params[:intent] == "publish" ? :active : :draft

    if @ride_post.save
      notice = @ride_post.draft? ? "Ride saved as a private draft. Choose Publish ride when ready." : "Ride post was successfully created."
      redirect_to @ride_post, notice: notice, status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /rides/:id
  def update
    @ride_post.assign_attributes(ride_post_params)
    @ride_post.status = :active if params[:intent] == "publish" && @ride_post.draft?

    if @ride_post.save
      redirect_to @ride_post, notice: "Ride post was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  def publish
    published = @ride_post.with_lock do
      if @ride_post.draft?
        @ride_post.status = :active
        @ride_post.save
      else
        @ride_post.errors.add(:base, "Only a private draft can be published.")
        false
      end
    end
    if published
      redirect_to user_path(Current.user), notice: "Ride published.", status: :see_other
    else
      redirect_to user_path(Current.user), alert: model_error_feedback(@ride_post, title: "Your ride wasn’t published. Edit the ride and check its details."), status: :see_other
    end
  end

  def close_requests
    RidePosts::CloseRequestsService.call(@ride_post, actor: Current.user)
    redirect_to @ride_post, notice: "Seat requests closed. Confirmed passengers and trip chat are unchanged.", status: :see_other
  rescue RidePosts::CloseRequestsService::Error => e
    redirect_to @ride_post, alert: "#{e.message}. Refresh the ride to check its current status.", status: :see_other
  end

  def reopen_requests
    RidePosts::ReopenRequestsService.call(@ride_post, actor: Current.user)
    redirect_to @ride_post, notice: "Seat requests reopened. Passengers can request seats again.", status: :see_other
  rescue RidePosts::ReopenRequestsService::Error => e
    redirect_to @ride_post, alert: "#{e.message}. Refresh the ride to check its current status.", status: :see_other
  end

  # DELETE /rides/:id
  def destroy
    if @ride_post.destroy
      redirect_to ride_posts_path, notice: "Ride post was successfully destroyed.", status: :see_other
    else
      redirect_to @ride_post, alert: model_error_feedback(@ride_post, title: "Your ride wasn’t deleted."), status: :see_other
    end
  end

  # PATCH /rides/1/cancel
  def cancel
    RidePosts::CancelService.call(@ride_post, actor: Current.user)
    redirect_to @ride_post, notice: "Trip was successfully canceled.", status: :see_other
  rescue RidePosts::CancelService::Error => e
    redirect_to @ride_post, alert: "#{e.message}. Refresh the ride to check its current status.", status: :see_other
  end

  private

  def load_trip_panels
    @pending_bookings = []
    @accepted_bookings = []
    if Current.user&.id == @ride_post.user_id
      if @ride_post.published?
        bookings = @ride_post.bookings.active.includes(passenger: { avatar_attachment: :blob }).to_a
        @pending_bookings = bookings.select(&:pending?)
        @accepted_bookings = bookings.select(&:accepted?)
      end
    elsif Current.user
      @existing_booking = @ride_post.bookings.active.find_by(passenger_id: Current.user.id)
    end
    @ride_bookable = @ride_post.bookable?
    @can_request_seat = @ride_post.authorized_for_booking?(Current.user)
    @can_chat = @ride_post.user_authorized_for_chat?(Current.user)
    @can_review = @ride_post.reviewable_by?(Current.user)
    @driver_communities = @ride_post.user.verified_communities.to_a
    return unless @can_chat

    @chat_unlocked = @ride_post.chat_unlocked?
    @chat_writable = @ride_post.chat_writable?
    @chat_participant_count = ([ @ride_post.user_id ] + @ride_post.previously_accepted_bookings.pluck(:passenger_id)).uniq.size
    @chat_messages = @ride_post.chat_messages.includes(user: { avatar_attachment: :blob }).order(created_at: :desc, id: :desc).limit(100).to_a.reverse
    @chat_message = @ride_post.chat_messages.build
  end

  def require_html_response
    head :not_acceptable unless request.negotiate_mime([ Mime[:html] ])
  end

  def create_regular_ride
    @ride_schedule = Current.user.ride_schedules.build
    attributes = params.expect(ride_post: [
      :origin_id, :destination_id, :departure_choice, :exact_departure_time,
      :seats, :notes, :ladies_only, :visibility, :community_id, :end_date,
      :source_ride_post_id, { weekday_ids: [] }
    ]).to_h
    attributes["departure_clock"] = attributes.delete("exact_departure_time")
    attributes["status"] = :active if params[:intent] == "publish"
    RideSchedules::ConfigureService.call(schedule: @ride_schedule, actor: Current.user, attributes: attributes)
    notice = @ride_schedule.draft? ? "Regular ride saved as a private draft." : "Regular schedule saved. Passengers book each departure separately."
    redirect_to @ride_schedule, notice: notice, status: :see_other
  rescue ActiveRecord::RecordInvalid => e
    @ride_schedule.errors.add(:base, e.record.errors.full_messages.to_sentence) if e.record != @ride_schedule
    render :new, status: :unprocessable_content
  rescue RideSchedules::ConfigureService::Error => e
    @ride_schedule.errors.add(:base, e.message)
    render :new, status: :unprocessable_content
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_ride_post
    @ride_post = RidePost.includes(:origin, :destination, :community, :ride_schedule, user: { avatar_attachment: :blob }).find_by(id: params.expect(:id).to_i)
    redirect_to ride_posts_path, alert: "The trip is no longer available" unless @ride_post
  end

  def set_user_ride_post
    @ride_post = Current.user.ride_posts.includes(:origin, :destination).find(params.expect(:id))
  end

  # Only allow a list of trusted parameters through.
  def ride_post_params
    params.expect(ride_post: [
      :origin_id, :destination_id, :departure_date, :departure_choice, :exact_departure_time, :departure_time,
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

  def resolve_search_locations
    query = (params[:q] || params[:query]).to_s.strip
    if query.present?
      if query =~ /\A(.+?)\s+(?:to|->|–|-)\s+(.+)\z/i
        orig_match = Location.city.where("LOWER(name) = ?", $1.strip.downcase).first ||
                     Location.city.where("LOWER(name) LIKE ?", "%#{$1.strip.downcase}%").first
        dest_match = Location.city.where("LOWER(name) = ?", $2.strip.downcase).first ||
                     Location.city.where("LOWER(name) LIKE ?", "%#{$2.strip.downcase}%").first
        @unresolved_location_search = true unless orig_match && dest_match
        if orig_match
          @origin ||= orig_match
          params[:origin_id] = orig_match.id
        end
        if dest_match
          @destination ||= dest_match
          params[:destination_id] = dest_match.id
        end
      else
        matched = Location.city.where("LOWER(name) = ?", query.downcase).first ||
                  Location.city.where("LOWER(name) LIKE ?", "%#{query.downcase}%").first
        @unresolved_location_search = true unless matched
        if matched
          if params[:origin_id].blank? && @origin.nil?
            @origin = matched
            params[:origin_id] = matched.id
          elsif params[:destination_id].blank? && @destination.nil?
            @destination = matched
            params[:destination_id] = matched.id
          end
        end
      end
    end

    if params[:origin].present? && params[:origin_id].blank? && @origin.nil?
      match = Location.city.where("LOWER(name) = ?", params[:origin].to_s.strip.downcase).first ||
              Location.city.where("LOWER(name) LIKE ?", "%#{params[:origin].to_s.strip.downcase}%").first
      @unresolved_location_search = true unless match
      if match
        @origin = match
        params[:origin_id] = match.id
      end
    end

    if params[:destination].present? && params[:destination_id].blank? && @destination.nil?
      match = Location.city.where("LOWER(name) = ?", params[:destination].to_s.strip.downcase).first ||
              Location.city.where("LOWER(name) LIKE ?", "%#{params[:destination].to_s.strip.downcase}%").first
      @unresolved_location_search = true unless match
      if match
        @destination = match
        params[:destination_id] = match.id
      end
    end

    if (params[:origin_id].present? && @origin.nil?) || (params[:destination_id].present? && @destination.nil?)
      locations = Location.where(id: [ params[:origin_id], params[:destination_id] ]).index_by(&:id)
      @origin ||= locations[params[:origin_id].to_i]
      @destination ||= locations[params[:destination_id].to_i]
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
    formatted_time =
      if @ride_post.departure_date.present?
        if @ride_post.exact_time? && @ride_post.departure_time.present?
          @ride_post.departure_time.strftime("%A, %b %d at %I:%M %p")
        else
          "#{@ride_post.departure_date.strftime('%A, %b %d')} (#{@ride_post.departure_choice_human})"
        end
      elsif @ride_post.departure_time.present?
        @ride_post.departure_time.strftime("%A, %b %d at %I:%M %p")
      else
        "Flexible departure"
      end

    title_text = "Ride from #{(@ride_post.origin&.name || "Choose origin")} to #{(@ride_post.destination&.name || "Choose destination")}"
    desc_text = "#{@ride_post.user.first_name} is offering a ride. " \
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
    return if @unresolved_location_search

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
