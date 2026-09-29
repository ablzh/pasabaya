# frozen_string_literal: true

class NoShowIncident < ApplicationRecord
  belongs_to :ride_post
  belongs_to :user
  belongs_to :reviewer, class_name: "User", optional: true

  enum :status, { pending: 0, upheld: 1, dismissed: 2, appealed: 3 }, default: :pending

  validates :status, presence: true
  validates :occurred_at, presence: true
  validates :ride_post_id, uniqueness: {
    scope: :user_id,
    message: "already has an incident recorded for this trip"
  }

  scope :upheld, -> { where(status: :upheld) }
  scope :recent_strikes_for, ->(u) { where(user_id: u.id, status: :upheld).where("occurred_at >= ?", 60.days.ago) }
end
