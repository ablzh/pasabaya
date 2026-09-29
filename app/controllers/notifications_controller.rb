# frozen_string_literal: true

class NotificationsController < ApplicationController
  before_action :require_authentication

  # GET /notifications
  def index
    @notifications = Current.user.received_notifications.recent.limit(50)
  end

  # GET /notifications/:id
  def show
    @notification = Current.user.received_notifications.find(params[:id])
    @notification.mark_as_read!

    case @notification.notifiable
    when Booking
      redirect_to ride_post_path(@notification.notifiable.ride_post)
    when RidePost
      redirect_to ride_post_path(@notification.notifiable)
    else
      redirect_to notifications_path
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
