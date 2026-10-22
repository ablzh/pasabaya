# frozen_string_literal: true

class UsersController < ApplicationController
  PAGE_SIZE = 20

  def show
    @user = User.find(params[:id])
    load_activity
  end

  def trips
    @user = Current.user
    load_activity
    render :show
  end

  private

  def load_activity
    @pagination = {}
    @activity_tab = Current.user == @user && params[:tab] == "bookings" ? "bookings" : "posts"
    @verified_communities = @user.verified_communities.to_a
    return load_public_activity unless Current.user == @user

    expire_overdue_requests
    rides = @user.ride_posts
    schedules = @user.ride_schedules
    upcoming = rides.where(status: [ :active, :fulfilled ], ride_schedule_id: nil).before_booking_cutoff
    upcoming_count = upcoming.count
    @posts_count = upcoming_count + schedules.where(status: [ :active, :paused ]).count
    @bookings_count = @user.bookings.count

    if @activity_tab == "bookings"
      @passenger_bookings = load_page(@user.bookings.includes(ride_post: [ :origin, :destination, user: { avatar_attachment: :blob } ]),
        "bookings_page", total: @bookings_count)
      return
    end

    # Regular series own their future dates. Only occurrences with participation
    # belong in departed/history lists; filtering happens before pagination.
    retained = rides.where(ride_schedule_id: nil).or(rides.where(id: Booking.select(:ride_post_id)))
    converted_sources = schedules.where.not(source_ride_post_id: nil).select(:source_ride_post_id)
    @ride_posts = load_page(with_listing_data(upcoming), "posts_page", total: upcoming_count)
    @ride_schedules = load_page(schedules.includes(:origin, :destination), "schedules_page")
    @draft_ride_posts = load_page(with_listing_data(rides.draft.where.not(id: converted_sources)).includes(:bookings), "drafts_page")
    @departed_ride_posts = load_page(with_listing_data(retained.where(status: [ :active, :fulfilled ])
      .where.not(id: RidePost.before_booking_cutoff.select(:id))), "departed_page")
    @past_ride_posts = load_page(with_listing_data(retained.where(status: [ :completed, :canceled ])), "history_page")
  end

  def load_public_activity
    visible = @user.ride_posts.where(status: [ :active, :fulfilled ]).upcoming.with_eligible_drivers
      .accepting_schedule_requests.visible_to(Current.user).one_per_schedule
    @ride_posts = load_page(with_listing_data(visible), "posts_page")
    @posts_count = @pagination.fetch("posts_page").fetch(:total)
  end

  def with_listing_data(rides)
    rides.includes(:origin, :destination, :community, :ride_schedule, user: { avatar_attachment: :blob })
  end

  def expire_overdue_requests
    overdue = RidePost.where.not(id: RidePost.before_booking_cutoff.select(:id))
    @user.bookings.pending.where(ride_post_id: overdue.select(:id)).includes(:ride_post).find_each do |booking|
      cutoff = booking.ride_post&.booking_cutoff_at
      Bookings::ExpireService.call(booking) if cutoff && cutoff <= Time.current
    end
  end

  def load_page(scope, parameter, total: nil)
    total ||= scope.count
    pages = [ (total + PAGE_SIZE - 1) / PAGE_SIZE, 1 ].max
    number = (Integer(params[parameter], exception: false) || 1).clamp(1, pages)
    @pagination[parameter] = { number: number, pages: pages, total: total }
    scope.reorder(created_at: :desc, id: :desc).limit(PAGE_SIZE).offset((number - 1) * PAGE_SIZE).to_a
  end
end
