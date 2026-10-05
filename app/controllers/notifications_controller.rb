# frozen_string_literal: true

class NotificationsController < ApplicationController
  before_action :require_authentication

  # GET /notifications
  def index
    @notifications = Current.user.received_notifications.includes(:actor, :notifiable).recent.limit(50)
  end

  def mark_all_as_read
    Current.user.mark_all_notifications_as_read!
    redirect_to notifications_path, status: :see_other
  end

  # GET /notifications/:id
  def show
    @notification = Current.user.received_notifications.find(params[:id])
    @notification.mark_as_read!
    unless @notification.route_alert_available?
      return redirect_to ride_posts_path, notice: "The trip is no longer available.", status: :see_other
    end

    case @notification.notifiable
    when Booking
      if (ride = @notification.notifiable.ride_post)
        redirect_to ride_post_path(ride)
      else
        redirect_to ride_posts_path, notice: "The trip is no longer available."
      end
    when RidePost
      redirect_to ride_post_path(@notification.notifiable)
    when NoShowIncidentDecision
      @decision = @notification.notifiable
      @incident = @decision.no_show_incident
      return head :not_found unless @incident.user_id == Current.user.id

      @ride = @incident.ride_post
      @superseded = @incident.decisions.where("id > ?", @decision.id).exists?
      response.headers["Cache-Control"] = "no-store"
      render :incident_decision
    else
      redirect_to ride_posts_path, notice: "The trip is no longer available."
    end
  end

  # PATCH /notifications/:id/mark_as_read
  def mark_as_read
    @notification = Current.user.received_notifications.find(params[:id])
    @notification.mark_as_read!

    respond_to do |format|
      format.html { redirect_back fallback_location: notifications_path, status: :see_other }
      format.turbo_stream
    end
  end
end
