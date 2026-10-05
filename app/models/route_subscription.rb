# frozen_string_literal: true

class RouteSubscription < ApplicationRecord
  belongs_to :user
  belongs_to :origin, class_name: "Location", optional: true
  belongs_to :destination, class_name: "Location", optional: true
  belongs_to :community, optional: true
  belongs_to :ride_post, optional: true

  enum :status, { active: 0, fulfilled: 1, canceled: 2, expired: 3 }, default: :active

  validates :origin_id, :destination_id, :user_id, :status, presence: true
  validates :ladies_only, inclusion: { in: [ true, false ] }
  before_validation :refresh_user, on: :create
  validate :user_must_not_be_deleted, on: :create
  validate :locations_must_differ
  validate :departure_date_cannot_be_in_the_past, on: :create
  validates :user_id, uniqueness: {
    scope: [ :origin_id, :destination_id, :departure_date, :community_id, :ladies_only, :status ],
    message: "already has an active route alert for this search"
  }, if: :active?

  scope :active, -> {
    where(status: :active)
      .where("departure_date IS NULL OR departure_date >= ?", Date.current)
  }

  def self.expire_overdue!
    where(status: :active).where("departure_date < ?", Date.current).update_all(status: statuses[:expired])
  end

  def matches?(ride)
    return false unless active?

    matches_ride?(ride)
  end

  def matches_ride?(ride)
    return false if expired_by_date?
    return false unless ride.offering? && ride.published? && ride.bookable? && ride.driver_eligible?
    return false if ride.user_id == user_id
    return false if ride.bookings.active.exists?(passenger_id: user_id)
    return false unless ride.origin_id == origin_id && ride.destination_id == destination_id

    if departure_date.present?
      return false unless ride.departure_date == departure_date
    else
      return false unless ride.booking_cutoff_at.present? && ride.booking_cutoff_at > Time.current
    end

    return false if ladies_only? && !ride.ladies_only?
    return false if community_id.present? && ride.community_id != community_id

    # Recheck audience access and booking eligibility
    passenger = user.reload
    return false unless passenger.eligible_for_booking?
    return false unless ride.authorized_for_booking?(passenger)

    true
  end

  def expired_by_date?
    departure_date.present? && departure_date < Date.current
  end

  def cancel!
    update!(status: :canceled)
  end

  private

  def refresh_user
    self.user = User.lock.find_by(id: user_id) if user_id
  end

  def user_must_not_be_deleted
    errors.add(:user, "is not eligible to request route alerts") if user&.deleted?
  end

  def locations_must_differ
    return unless origin_id && destination_id

    errors.add(:destination, "must differ from origin") if origin_id == destination_id
  end

  def departure_date_cannot_be_in_the_past
    return if departure_date.blank?

    if departure_date < Date.current
      errors.add(:departure_date, "can't be in the past")
    end
  end
end
