# frozen_string_literal: true

class BookingsController < ApplicationController
  before_action :require_authentication
  before_action :set_ride_post, only: :create
  before_action :set_booking, only: %i[ show accept decline cancel ]

  # POST /rides/:ride_post_id/bookings
  def create
    Booking.transaction do
      @booking = @ride_post.bookings.build(booking_params.merge(passenger: Current.user))
      @booking.save!

      now = Time.current
      delivery_key = "booking_requested:#{@booking.id}:#{now.to_i}"
      Notification.find_or_create_by!(delivery_key: delivery_key) do |n|
        n.recipient = @ride_post.user
        n.actor = Current.user
        n.notifiable = @booking
        n.event_name = "booking.requested"
        n.delivery_status = :pending
      end
    end

    redirect_to @ride_post, notice: "Seat requested! The driver has been notified."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @ride_post, alert: (@booking&.errors&.full_messages&.to_sentence || e.message)
  end

  # GET /bookings/:id
  def show
    unless @booking.passenger_id == Current.user.id || @booking.ride_post.user_id == Current.user.id
      redirect_to ride_posts_path, alert: "Not authorized"
    end
  end

  # PATCH /bookings/:id/accept
  def accept
    Bookings::AcceptService.call(@booking, actor: Current.user)
    redirect_to @booking.ride_post, notice: "Booking accepted! Passenger seat confirmed."
  rescue Bookings::AcceptService::Error => e
    redirect_to @booking.ride_post, alert: e.message
  end

  # PATCH /bookings/:id/decline
  def decline
    Bookings::DeclineService.call(@booking, actor: Current.user)
    redirect_to @booking.ride_post, notice: "Booking request declined."
  rescue Bookings::DeclineService::Error => e
    redirect_to @booking.ride_post, alert: e.message
  end

  # PATCH /bookings/:id/cancel
  def cancel
    Bookings::CancelService.call(@booking, actor: Current.user)
    redirect_to @booking.ride_post, notice: "Booking has been canceled."
  rescue Bookings::CancelService::Error => e
    redirect_to @booking.ride_post, alert: e.message
  end

  private

  def set_ride_post
    @ride_post = RidePost.find(params[:ride_post_id])
  end

  def set_booking
    @booking = Booking.includes(:ride_post, :passenger).find(params[:id])
  end

  def booking_params
    params.fetch(:booking, {}).permit(:pickup_notes)
  end
end
