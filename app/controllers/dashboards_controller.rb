class DashboardsController < ApplicationController
  def show
    @active_rides = Current.user.ride_posts.active.order(departure_time: :asc)

    @inactive_rides = Current.user.ride_posts.where.not(status: :active).order(departure_time: :desc)
  end
end
