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
        incident_record = NoShowIncident.lock.find(incident.id)
        previous_status = incident_record.status.to_sym

        return incident_record if previous_status == status

        now = Time.current
        incident_record.update!(
          status: status,
          reviewer: reviewer,
          decision_reason: reason,
          resolved_at: now
        )

        user = User.lock.find(incident_record.user_id)
        return incident_record if user.deleted?

        if status == :upheld
          strikes = user.recent_upheld_incidents_count

          if strikes >= 3 && !user.booking_frozen?
            user.update!(booking_freeze_until: 7.days.from_now)
          end

          delivery_key = "incident_resolved:#{incident_record.id}:upheld"
          Notification.find_or_create_by!(delivery_key: delivery_key) do |n|
            n.recipient = user
            n.actor = reviewer
            n.notifiable = incident_record.ride_post
            n.event_name = "incident.resolved"
            n.delivery_status = :pending
          end
        elsif status == :dismissed
          if user.booking_frozen? && user.recent_upheld_incidents_count < 3
            user.update!(booking_freeze_until: nil)
          end
        end

        incident_record
      end
    end

    private

    attr_reader :incident, :status, :reviewer, :reason
  end
end
