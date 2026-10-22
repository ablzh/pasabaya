class RideSchedulesController < ApplicationController
  before_action :require_authentication, except: :show
  before_action :resume_session, only: :show
  before_action :set_owned_schedule, only: %i[edit update pause resume cancel_future]
  before_action :set_form_options, only: %i[edit update]

  def edit
  end

  def update
    attributes = schedule_params.to_h
    attributes["status"] = :active if params[:intent] == "publish"
    RideSchedules::ConfigureService.call(schedule: @ride_schedule, actor: Current.user, attributes: attributes)
    redirect_to @ride_schedule, notice: @ride_schedule.draft? ? "Regular ride saved as a private draft." : "Regular schedule saved. Departures with requests keep their existing conditions.", status: :see_other
  rescue ActiveRecord::RecordInvalid => e
    if e.record != @ride_schedule
      @ride_schedule.errors.add(:base, e.record.errors.full_messages.to_sentence)
    end
    render :edit, status: :unprocessable_content
  rescue RideSchedules::ConfigureService::Error => e
    @ride_schedule.errors.add(:base, e.message)
    render :edit, status: :unprocessable_content
  end

  def show
    @ride_schedule = RideSchedule.includes(:origin, :destination, :community, :user).find(params[:id])
    unless @ride_schedule.authorized_viewer?(Current.user)
      head :forbidden
      return
    end
    RideSchedules::MaterializeService.call(@ride_schedule) if @ride_schedule.active?
    states = Current.user&.id == @ride_schedule.user_id ? [ :active, :fulfilled, :canceled ] : [ :active, :fulfilled ]
    @departures = @ride_schedule.ride_posts.where(status: states).upcoming
                                .visible_to(Current.user).includes(:origin, :destination, :user, ride_schedule: :user, bookings: { passenger: { avatar_attachment: :blob } })
                                .order(:departure_date, :departure_time)
  end

  def pause
    transition(:pause, "Schedule paused. Confirmed departures remain scheduled; pending requests have expired.")
  end

  def resume
    transition(:resume, "Schedule resumed. Cancelled departures and expired requests remain unchanged.")
  end

  def cancel_future
    transition(:cancel_future, "Schedule ended and future departures cancelled. Passengers have been notified.")
  end

  private

  def set_owned_schedule
    @ride_schedule = Current.user.ride_schedules.find(params[:id])
  end

  def set_form_options
    @grouped_locations = Location.grouped_by_region
    @communities = Current.user.verified_communities
  end

  def schedule_params
    params.expect(ride_schedule: [ :origin_id, :destination_id, :departure_choice, :departure_clock, :seats, :notes, :visibility, :community_id, :ladies_only, :end_date, { weekday_ids: [] } ])
  end

  def transition(action, notice)
    RideSchedules::TransitionService.call(schedule: @ride_schedule, actor: Current.user, action: action)
    redirect_to @ride_schedule, notice: notice, status: :see_other
  rescue RideSchedules::TransitionService::Error, ActiveRecord::RecordInvalid => e
    redirect_to @ride_schedule, alert: e.message, status: :see_other
  end
end
