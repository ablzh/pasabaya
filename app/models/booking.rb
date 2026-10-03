class Booking < ApplicationRecord
  belongs_to :ride_post
  belongs_to :passenger, class_name: "User"
  belongs_to :canceled_by, class_name: "User", optional: true

  has_many :notifications, as: :notifiable

  enum :status, { pending: 0, accepted: 1, declined: 2, canceled: 3, expired: 4 }, default: :pending

  validates :status, presence: true
  validates :passenger_id, uniqueness: {
    scope: :ride_post_id,
    conditions: -> { where(status: [ :pending, :accepted ]) },
    message: "already has an active booking for this ride"
  }

  validate :passenger_cannot_be_driver, on: :create
  validate :validate_passenger_eligibility, on: :create
  validate :validate_ride_bookable, on: :create
  validate :validate_audience_eligibility, on: :create

  before_save :record_acceptance, if: -> { accepted? && accepted_at.blank? }
  before_destroy :check_destruction_allowed, prepend: true

  scope :active, -> { where(status: [ :pending, :accepted ]) }
  scope :pending, -> { where(status: :pending) }
  scope :accepted, -> { where(status: :accepted) }
  scope :declined, -> { where(status: :declined) }
  scope :canceled, -> { where(status: :canceled) }

  def active?
    pending? || accepted?
  end

  def historical_reviewable?
    dep_time = ride_post&.departure_time
    return false if dep_time.blank? || dep_time > Time.current

    accepted? || (canceled? && accepted_at.present? && accepted_at <= dep_time && canceled_at.present? && canceled_at >= dep_time)
  end

  private

  def check_destruction_allowed
    if historical_reviewable?
      errors.add(:base, "Cannot delete booking with historical participation. Records must be preserved for review eligibility.")
      throw :abort
    end
  end

  def record_acceptance
    self.accepted_at = decided_at || Time.current
  end

  def passenger_cannot_be_driver
    return unless ride_post && passenger_id

    if ride_post.user_id == passenger_id
      errors.add(:base, "Drivers cannot request seats on their own ride")
    end
  end

  def validate_passenger_eligibility
    return unless passenger

    unless passenger.eligible_for_booking?
      errors.add(:passenger, "is not eligible to request seats")
    end
  end

  def validate_ride_bookable
    return unless ride_post

    unless ride_post.bookable?
      errors.add(:ride_post, "is not available for booking")
    end
  end

  def validate_audience_eligibility
    return unless ride_post && passenger

    unless ride_post.authorized_for_booking?(passenger)
      errors.add(:base, "You are not eligible to book this ride")
    end
  end
end
