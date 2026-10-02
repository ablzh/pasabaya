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
    @ride_posts = @ride_posts.active.upcoming.visible_to(Current.user) unless Current.user == @user

    if authenticated? && Current.user == @user
      @passenger_bookings = @user.bookings.includes(ride_post: [ :origin, :destination, user: { avatar_attachment: :blob } ]).order(created_at: :desc)
    end
  end
end
