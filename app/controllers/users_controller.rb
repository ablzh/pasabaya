class UsersController < ApplicationController
  def show
    @user = User.find(params[:id])
    @ride_posts = @user.ride_posts.includes(:origin, :destination).active.order(departure_time: :asc)
  end
end
