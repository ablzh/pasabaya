# frozen_string_literal: true

class BookingsController < ApplicationController
  before_action :require_authentication
  before_action :set_ride_post, only: :create
  before_action :set_booking, only: %i[ show accept decline cancel ]

  # POST /rides/:ride_post_id/bookings
  def create
    @booking = Bookings::CreateService.call(ride_post: @ride_post, passenger: Current.user, pickup_notes: booking_params[:pickup_notes])
    redirect_to @booking.ride_post, notice: "Seat requested! The driver has been notified.", status: :see_other
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @ride_post, alert: e.record.errors.full_messages.to_sentence, status: :see_other
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
    redirect_to @booking.ride_post, notice: "Booking accepted! Passenger seat confirmed.", status: :see_other
  rescue Bookings::AcceptService::Error => e
    redirect_to @booking.ride_post, alert: e.message, status: :see_other
  end

  # PATCH /bookings/:id/decline
  def decline
    Bookings::DeclineService.call(@booking, actor: Current.user)
    redirect_to @booking.ride_post, notice: "Booking request declined.", status: :see_other
  rescue Bookings::DeclineService::Error => e
    redirect_to @booking.ride_post, alert: e.message, status: :see_other
  end

  # PATCH /bookings/:id/cancel
  def cancel
    Bookings::CancelService.call(@booking, actor: Current.user)
    redirect_to @booking.ride_post, notice: "Booking has been canceled.", status: :see_other
  rescue Bookings::CancelService::Error => e
    redirect_to @booking.ride_post, alert: e.message, status: :see_other
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
