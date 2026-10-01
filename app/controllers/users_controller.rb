# frozen_string_literal: true

class UsersController < ApplicationController
  def show
    @user = User.find(params[:id])
    @ride_posts = @user.ride_posts.includes(:origin, :destination, :community).active.visible_to(Current.user).order(departure_time: :asc)

    if authenticated? && Current.user == @user
      @passenger_bookings = @user.bookings.includes(ride_post: [ :origin, :destination, user: { avatar_attachment: :blob } ]).order(created_at: :desc)
    end
  end
end
