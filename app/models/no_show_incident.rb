# frozen_string_literal: true

class NoShowIncident < ApplicationRecord
  belongs_to :ride_post
  belongs_to :user
  belongs_to :reviewer, class_name: "User", optional: true
  has_many :decisions, class_name: "NoShowIncidentDecision", dependent: :restrict_with_error

  enum :status, { pending: 0, upheld: 1, dismissed: 2, appealed: 3 }, default: :pending

  validates :status, presence: true
  validates :occurred_at, presence: true
  validates :ride_post_id, uniqueness: {
    scope: :user_id,
    message: "already has an incident recorded for this trip"
  }

  scope :upheld, -> { where(status: :upheld) }
  scope :recent_strikes_for, ->(u) { where(user_id: u.id, status: :upheld).where("occurred_at >= ?", 60.days.ago) }

  def adjudicable_by?(reviewer)
    reviewer&.active_admin? && reviewer.id != user_id && reviewer.id != ride_post.user_id &&
      !ride_post.bookings.exists?(passenger_id: reviewer.id) && !ride_post.trip_reviews.exists?(reporter_id: reviewer.id)
  end

  def personal_details_removed?
    user.deleted? || ride_post.user.deleted? || reviewer&.deleted? ||
      TripReview.joins(:reporter).where(ride_post_id: ride_post_id, reported_user_id: user_id).where.not(users: { deleted_at: nil }).exists? ||
      decisions.joins(:reviewer).where.not(users: { deleted_at: nil }).exists?
  end
end
