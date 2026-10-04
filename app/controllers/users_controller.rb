# frozen_string_literal: true

class UsersController < ApplicationController
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
    @ride_posts = @user.ride_posts.includes(:origin, :destination, :community, user: { avatar_attachment: :blob }).order(created_at: :desc)
    if Current.user == @user
      rides = @ride_posts.to_a
      @draft_ride_posts = rides.select(&:draft?)
      @past_ride_posts = rides.select { |ride| ride.canceled? || ride.completed? }
      published_rides = rides.select(&:published?)
      @ride_posts, @departed_ride_posts = published_rides.partition { |ride| ride.booking_cutoff_at.present? && ride.booking_cutoff_at > Time.current }
    else
      @ride_posts = @ride_posts.where(status: [ :active, :fulfilled ]).upcoming.visible_to(Current.user)
    end

    if authenticated? && Current.user == @user
      @user.bookings.pending.includes(:ride_post).find_each do |b|
        Bookings::ExpireService.call(b) if b.ride_post&.booking_cutoff_at && Time.current >= b.ride_post.booking_cutoff_at
      end
      @passenger_bookings = @user.bookings.includes(ride_post: [ :origin, :destination, user: { avatar_attachment: :blob } ]).order(created_at: :desc)
    end
  end
end
