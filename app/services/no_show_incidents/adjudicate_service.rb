# frozen_string_literal: true

module NoShowIncidents
  class AdjudicateService
    class Error < StandardError; end

    def self.call(...)
      new(...).call
    end

    def initialize(incident, status:, reviewer: nil, reason: nil)
      @incident = incident
      @status = status.to_sym
      @reviewer = reviewer
      @reason = reason
    end

    def call
      ActiveRecord::Base.transaction do
        incident.update!(
          status: status,
          reviewer: reviewer,
          decision_reason: reason,
          resolved_at: Time.current
        )

        user = incident.user

        if status == :upheld
          # Count strikes in rolling 60 days
          strikes = user.recent_upheld_incidents_count

          if strikes >= 3
            user.update!(booking_freeze_until: 7.days.from_now)
          end

          # Create notification for affected user
          delivery_key = "incident_resolved:#{incident.id}:#{Time.current.to_i}"
          Notification.find_or_create_by!(delivery_key: delivery_key) do |n|
            n.recipient = user
            n.actor = reviewer
            n.notifiable = incident.ride_post
            n.event_name = "incident.resolved"
            n.delivery_status = :pending
          end
        elsif status == :dismissed
          # If an appeal or dismissal happened and user has fewer than 3 strikes now, unfreeze
          if user.booking_frozen? && user.recent_upheld_incidents_count < 3
            user.update!(booking_freeze_until: nil)
          end
        end

        incident
      end
    end

    private

    attr_reader :incident, :status, :reviewer, :reason
  end
end
