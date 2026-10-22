# frozen_string_literal: true

class TripReview < ApplicationRecord
  belongs_to :ride_post
  belongs_to :reporter, class_name: "User"
  belongs_to :reported_user, class_name: "User"

  enum :outcome, {
    completed: 0,
    passenger_no_show: 1,
    driver_no_show: 2,
    canceled_last_minute: 3,
    other_issue: 4
  }, default: :completed

  validates :outcome, presence: true
  validates :ride_post_id, uniqueness: {
    scope: [ :reporter_id, :reported_user_id ],
    message: "has already been reviewed by this user for this trip"
  }

  before_validation :refresh_participants
  validate :reporter_must_be_eligible

  validate :reporter_and_reported_must_be_different
  validate :participants_must_belong_to_trip
  validate :trip_must_have_departed
  validate :no_show_outcome_matches_role

  private

  def no_show_outcome_matches_role
    return unless ride_post && reported_user_id

    if driver_no_show? && reported_user_id != ride_post.user_id
      errors.add(:outcome, :passenger_outcome, message: "must describe a passenger when reviewing a passenger")
    elsif passenger_no_show? && reported_user_id == ride_post.user_id
      errors.add(:outcome, :driver_outcome, message: "must describe a driver when reviewing the driver")
    end
  end

  def refresh_participants
    self.reporter = User.lock.find_by(id: reporter_id) if reporter_id
    self.reported_user = User.lock.find_by(id: reported_user_id) if reported_user_id
    # Preserve the safety outcome without restoring free-form data about a deleted account.
    self.notes = nil if reported_user&.deleted?
  end

  def reporter_must_be_eligible
    if reporter && (reporter.deleted? || reporter.banned_at.present?)
      errors.add(:reporter, :ineligible_reporter, message: "is not eligible to submit reviews")
    end
  end

  def reporter_and_reported_must_be_different
    if reporter_id.present? && reported_user_id.present? && reporter_id == reported_user_id
      errors.add(:reported_user, :self_review, message: "cannot be yourself")
    end
  end

  def participants_must_belong_to_trip
    return unless ride_post && reporter && reported_user

    unless ride_post.participant?(reporter)
      errors.add(:reporter, :not_participant, message: "must be a driver or accepted passenger on this trip")
    end

    unless ride_post.participant?(reported_user)
      errors.add(:reported_user, :not_participant, message: "must be a driver or accepted passenger on this trip")
    end
  end

  def trip_must_have_departed
    return unless ride_post

    if ride_post.booking_cutoff_at.present? && Time.current < ride_post.booking_cutoff_at
      errors.add(:base, :before_departure, message: "Reviews and no-show reports cannot be submitted before trip departure")
    elsif !ride_post.reviewable_trip?
      errors.add(:base, :not_departed, message: "Reviews require a departed ride offer")
    end
  end
end
