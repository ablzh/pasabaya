# frozen_string_literal: true

module Admin
  class NoShowIncidentsController < BaseController
    before_action :set_incident, only: %i[show update]

    def index
      @filters = params.permit(:status, :ride_post_id, :user_id, :from, :to)
      @filters[:status] = "open" if @filters[:status].blank?
      @filter_errors = []
      records = NoShowIncident.all
      case @filters[:status]
      when "open" then records = records.where(status: [ :pending, :appealed ])
      when "all" then nil
      else
        if NoShowIncident.statuses.key?(@filters[:status])
          records = records.where(status: @filters[:status])
        else
          @filter_errors << "Choose a valid incident status."
          records = records.where(status: [ :pending, :appealed ])
        end
      end
      records = filter_id(records, :ride_post_id, :ride_post_id)
      records = filter_id(records, :user_id, :user_id)
      @incidents = filter_dates(records, :occurred_at)
        .preload(:user, ride_post: [ :origin, :destination ])
        .order(occurred_at: :desc, id: :desc)
    end

    def show
      load_case_context
    end

    def update
      attributes = params.expect(no_show_incident: [ :status, :reason, :lock_version ])
      @entered_reason = attributes[:reason]
      @entered_status = attributes[:status]
      version = attributes[:lock_version]
      unless version.is_a?(String) && version.match?(/\A[0-9]+\z/)
        return render_decision_error("This form is missing its case version. Reload the case and try again.", :unprocessable_content)
      end

      NoShowIncidents::AdjudicateService.call(@incident,
        status: attributes[:status], reason: attributes[:reason], reviewer: Current.user,
        expected_version: version.to_i)
      redirect_to admin_no_show_incident_path(@incident), notice: "Decision saved.", status: :see_other
    rescue NoShowIncidents::AdjudicateService::Conflict => error
      render_decision_error(error.message, :conflict)
    rescue NoShowIncidents::AdjudicateService::Error => error
      render_decision_error(error.message, :unprocessable_content)
    end

    private

    def set_incident
      @incident = NoShowIncident.find(params.expect(:id))
    end

    def load_case_context
      @incident = NoShowIncident.preload(:user, :reviewer,
        ride_post: [ :user, :origin, :destination, :community, { bookings: [ :passenger, :canceled_by ] } ]).find(@incident.id)
      @ride_post = @incident.ride_post
      @reviews = TripReview.where(ride_post_id: @incident.ride_post_id, reported_user_id: @incident.user_id)
        .preload(:reporter, :reported_user).order(created_at: :asc, id: :asc)
      @decisions = @incident.decisions.preload(:reviewer).order(created_at: :desc, id: :desc)
      @participants = [ @ride_post.user, *@ride_post.bookings.map(&:passenger), @incident.user ].uniq(&:id)
      @strike_counts = NoShowIncident.upheld.where(user_id: @participants.map(&:id))
        .where("occurred_at >= ?", 60.days.ago).group(:user_id).count
      @adjudicable = @incident.adjudicable_by?(Current.user)
    end

    def render_decision_error(message, status)
      @decision_error = message
      load_case_context
      render :show, formats: [ :html ], status: status
    end
  end
end
