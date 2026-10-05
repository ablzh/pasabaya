# frozen_string_literal: true

class NoShowIncidentDecision < ApplicationRecord
  belongs_to :no_show_incident
  belongs_to :reviewer, class_name: "User", optional: true

  enum :status, { pending: 0, upheld: 1, dismissed: 2, appealed: 3 }
  enum :previous_status, { pending: 0, upheld: 1, dismissed: 2, appealed: 3 }, prefix: true

  validates :status, presence: true
  validates :previous_status, presence: true, unless: :legacy?
  validates :reviewer, :reason, presence: true, on: :create, unless: :legacy?
  validates :status, inclusion: { in: %w[upheld dismissed] }, unless: :legacy?
  validates :reason, length: { maximum: 2000 }, unless: :legacy?

  # Decisions are historical records. Anonymization uses explicit bulk scrubbing.
  attr_readonly :no_show_incident_id, :reviewer_id, :previous_status, :status, :reason, :booking_freeze_until, :legacy
end
