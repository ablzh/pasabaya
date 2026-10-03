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

  validate :reporter_and_reported_must_be_different
  validate :participants_must_belong_to_trip
  validate :trip_must_have_departed

  private

  def reporter_and_reported_must_be_different
    if reporter_id.present? && reported_user_id.present? && reporter_id == reported_user_id
      errors.add(:reported_user, "cannot be yourself")
    end
  end

  def participants_must_belong_to_trip
    return unless ride_post && reporter && reported_user

    unless ride_post.participant?(reporter)
      errors.add(:reporter, "must be a driver or accepted passenger on this trip")
    end

    unless ride_post.participant?(reported_user)
      errors.add(:reported_user, "must be a driver or accepted passenger on this trip")
    end
  end

  def trip_must_have_departed
    return unless ride_post

    if ride_post.departure_time.present? && Time.current < ride_post.departure_time
      errors.add(:base, "Reviews and no-show reports cannot be submitted before trip departure")
    elsif !ride_post.reviewable_trip?
      errors.add(:base, "Reviews require a departed ride offer")
    end
  end
end
