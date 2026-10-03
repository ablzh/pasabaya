# frozen_string_literal: true

class TripReviewsController < ApplicationController
  before_action :require_authentication
  before_action :set_ride_post
  before_action :require_participant
  before_action :require_review_eligibility, only: %i[ new create ]

  def new
    @possible_reviewees = @ride_post.review_participants.where.not(id: Current.user.id)
    default_reviewee = @possible_reviewees.first
    @trip_review = @ride_post.trip_reviews.build(
      reporter: Current.user,
      reported_user_id: params[:reported_user_id] || default_reviewee&.id
    )
  end

  def create
    @possible_reviewees = @ride_post.review_participants.where.not(id: Current.user.id)
    @trip_review = @ride_post.trip_reviews.build(trip_review_params)
    @trip_review.reporter = Current.user

    TripReview.transaction do
      @trip_review.save!
      if @trip_review.passenger_no_show? || @trip_review.driver_no_show?
        NoShowIncident.find_or_create_by!(ride_post: @ride_post, user: @trip_review.reported_user) do |incident|
          incident.status = :pending
          incident.occurred_at = @ride_post.departure_time || Time.current
          incident.decision_reason = "Reported by #{@trip_review.reporter.first_name}: #{@trip_review.notes}"
        end
      end
    end

    redirect_to @ride_post, notice: "Thank you for submitting your trip review.", status: :see_other
  rescue ActiveRecord::RecordInvalid => e
    @trip_review.errors.add(:base, "Could not save the incident report. Please try again.") unless e.record == @trip_review
    render :new, status: :unprocessable_content
  end

  private

  def set_ride_post
    @ride_post = RidePost.find(params.expect(:ride_post_id))
  end

  def require_participant
    unless @ride_post.participant?(Current.user)
      redirect_to @ride_post, alert: "Only trip participants can submit a review."
    end
  end

  def require_review_eligibility
    if @ride_post.departure_time.present? && Time.current < @ride_post.departure_time
      redirect_to @ride_post, alert: "Reviews and no-show reports cannot be submitted before trip departure."
    elsif !@ride_post.reviewable_by?(Current.user)
      redirect_to @ride_post, alert: "Reviews require a departed ride offer with another eligible participant."
    end
  end

  def trip_review_params
    params.expect(trip_review: [ :reported_user_id, :outcome, :notes ])
  end
end
