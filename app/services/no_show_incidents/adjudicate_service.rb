# frozen_string_literal: true

module NoShowIncidents
  class AdjudicateService
    class Error < StandardError
      attr_reader :attribute

      def initialize(message, attribute: :base)
        @attribute = attribute
        super(message)
      end
    end
    class Conflict < Error; end

    def self.call(...)
      new(...).call
    end

    def initialize(incident, status:, reviewer:, reason:, expected_version: incident.lock_version)
      @incident = incident
      @status = status.to_s
      @reviewer = reviewer
      @reason = reason.to_s.strip
      @expected_version = expected_version
    end

    def call
      raise Error.new("Choose Confirm no-show or Dismiss report.", attribute: :status) unless %w[upheld dismissed].include?(status)
      raise Error.new("Enter a decision reason.", attribute: :reason) if reason.blank?
      raise Error.new("Keep the decision reason to 2000 characters or fewer.", attribute: :reason) if reason.length > 2000

      ActiveRecord::Base.transaction do
        incident_record = NoShowIncident.lock.preload(:user, :reviewer, ride_post: :user).find(incident.id)
        moderator = User.lock.find_by(id: reviewer&.id)
        raise Error, "An active administrator is required." unless moderator&.active_admin?
        raise Error, "You cannot decide an incident involving your own trip." unless incident_record.adjudicable_by?(moderator)

        if incident_record.lock_version != version
          # A replay of the same submitted decision is harmless; a different stale
          # decision must be reviewed against the updated case before it can write.
          last_decision = incident_record.decisions.order(id: :desc).first
          if incident_record.lock_version == version + 1 && last_decision&.status == status &&
              last_decision.reviewer_id == moderator.id && last_decision.reason == stored_reason(incident_record)
            return incident_record
          end
          raise Conflict, "This incident has changed. Review the latest decision before submitting again."
        end

        previous_status = incident_record.status
        return incident_record if previous_status == status

        now = Time.current
        personal_details_removed = incident_record.personal_details_removed?
        decision_reason = stored_reason(incident_record, personal_details_removed: personal_details_removed)
        preserve_legacy_decision(incident_record, personal_details_removed: personal_details_removed)
        incident_record.update!(
          status: status,
          reviewer: moderator,
          decision_reason: decision_reason,
          resolved_at: now
        )

        user = User.lock.find(incident_record.user_id)
        if !user.deleted? && status == "upheld"
          strikes = user.recent_upheld_incidents_count

          if strikes >= 3 && !user.booking_frozen?
            user.update!(booking_freeze_until: 7.days.from_now)
          end
        elsif !user.deleted? && status == "dismissed"
          if user.booking_frozen? && user.recent_upheld_incidents_count < 3
            user.update!(booking_freeze_until: nil)
          end
        end

        decision = incident_record.decisions.create!(
          previous_status: previous_status, status: status, reviewer: moderator,
          reason: incident_record.decision_reason, booking_freeze_until: user.booking_frozen? ? user.booking_freeze_until : nil
        )
        unless user.deleted?
          Notification.create!(
            delivery_key: "incident_resolved:decision:#{decision.id}", recipient: user,
            actor: moderator, notifiable: decision, event_name: "incident.resolved", delivery_status: :pending
          )
        end

        incident_record
      end
    rescue ActiveRecord::RecordInvalid => e
      raise Error, "The decision couldn’t be saved. Reload the case and try again."
    end

    private

    attr_reader :incident, :status, :reviewer, :reason, :expected_version

    def version
      Integer(expected_version.to_s, 10)
    rescue ArgumentError, TypeError
      raise Error, "The incident version is required."
    end

    def preserve_legacy_decision(incident_record, personal_details_removed:)
      return unless incident_record.resolved_at && !incident_record.decisions.exists?

      incident_record.decisions.create!(
        status: incident_record.status, reviewer: incident_record.reviewer,
        reason: personal_details_removed ? nil : incident_record.decision_reason,
        legacy: true, created_at: incident_record.resolved_at, updated_at: incident_record.resolved_at
      )
    end

    def stored_reason(incident_record, personal_details_removed: incident_record.personal_details_removed?)
      if personal_details_removed
        "Personal details removed after account deletion; outcome preserved."
      else
        reason
      end
    end
  end
end
