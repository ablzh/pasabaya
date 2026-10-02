# frozen_string_literal: true

class NotificationsController < ApplicationController
  before_action :require_authentication

  # GET /notifications
  def index
    @notifications = Current.user.received_notifications.includes(:actor).recent.limit(50)
  end

  # GET /notifications/:id
  def show
    @notification = Current.user.received_notifications.find(params[:id])
    @notification.mark_as_read!

    case @notification.notifiable
    when Booking
      if (ride = @notification.notifiable.ride_post)
        redirect_to ride_post_path(ride)
      else
        redirect_to ride_posts_path, notice: "The trip is no longer available."
      end
    when RidePost
      redirect_to ride_post_path(@notification.notifiable)
    else
      redirect_to ride_posts_path, notice: "The trip is no longer available."
    end
  end

  # PATCH /notifications/:id/mark_as_read
  def mark_as_read
    @notification = Current.user.received_notifications.find(params[:id])
    @notification.mark_as_read!

    respond_to do |format|
      format.html { redirect_back fallback_location: notifications_path }
      format.turbo_stream
    end
  end
end
