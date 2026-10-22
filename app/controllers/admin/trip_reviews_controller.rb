# frozen_string_literal: true

module Admin
  class TripReviewsController < BaseController
    def index
      @filters = params.permit(:outcome, :ride_post_id, :user_id, :from, :to)
      @filter_errors = []
      records = TripReview.all
      if @filters[:outcome].present?
        if TripReview.outcomes.key?(@filters[:outcome])
          records = records.where(outcome: @filters[:outcome])
        else
          @filter_errors << "Choose a valid review outcome."
        end
      end
      records = filter_id(records, :ride_post_id, :ride_post_id)
      records = filter_id(records, :user_id, [ :reporter_id, :reported_user_id ])
      @trip_reviews = filter_dates(records, :created_at)
        .preload(:reporter, :reported_user, ride_post: [ :origin, :destination ])
        .order(created_at: :desc, id: :desc)
    end

    def show
      @trip_review = TripReview.preload(:reporter, :reported_user, ride_post: [ :origin, :destination ]).find(params.expect(:id))
      @incident = NoShowIncident.find_by(ride_post_id: @trip_review.ride_post_id, user_id: @trip_review.reported_user_id)
    end
  end
end
