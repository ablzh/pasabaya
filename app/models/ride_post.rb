class RidePost < ApplicationRecord
  belongs_to :user

  belongs_to :origin, class_name: "Location", optional: true
  belongs_to :destination, class_name: "Location", optional: true
  belongs_to :community, optional: true

  has_many :bookings, dependent: :destroy
  has_many :notifications, as: :notifiable
  has_many :chat_messages, dependent: :destroy
  has_many :trip_reviews, dependent: :restrict_with_error
  has_many :no_show_incidents, dependent: :restrict_with_error

  before_destroy :check_destruction_allowed, prepend: true

  enum :post_type, { offering: 0 }, default: :offering, validate: true
  enum :status, { active: 0, fulfilled: 1, canceled: 2, completed: 3, draft: 4 }
  enum :visibility, { public_ride: 0, hub_only: 1 }, default: :public_ride

  validate :departure_time_cannot_be_in_the_past
  validates :seats, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :origin, :destination, :seats, presence: true, unless: :draft?
  validate :route_must_have_distinct_locations, unless: :draft?
  validates :post_type, presence: true
  validates :status, presence: true
  validates :visibility, presence: true
  validates :remaining_seats, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: :seats }, allow_nil: true
  validates :ladies_only, inclusion: { in: [ true, false ] }

  validates :community, presence: true, if: :hub_only?

  validate :driver_must_be_verified_community_member, if: -> { hub_only? && !canceled? && !completed? && (publishing? || will_save_change_to_community_id? || will_save_change_to_visibility?) }
  validate :driver_must_be_female_for_ladies_only, if: -> { ladies_only? && !canceled? && !completed? && (publishing? || will_save_change_to_ladies_only?) }
  validate :bookable_offering_requirements, if: -> { offering? && !draft? && !canceled? && !completed? }
  validate :lock_attributes_when_accepted_bookings_exist, on: :update

  before_validation :initialize_remaining_seats, on: :create
  before_validation :sync_remaining_seats_with_capacity, on: :update
  before_validation :preload_locations, if: -> { origin_id.present? && destination_id.present? }

  after_save_commit :schedule_trip_audit, if: :should_schedule_audit?

  scope :publicly_visible, -> { public_ride.where(ladies_only: false) }
  scope :filter_by_origin, ->(origin_id) { where(origin_id: origin_id) if origin_id.present? }
  scope :filter_by_destination, ->(destination_id) { where(destination_id: destination_id)  if destination_id.present? }
  scope :filter_by_community, ->(comm_id) { where(community_id: comm_id) if comm_id.present? }
  scope :filter_by_ladies_only, ->(ladies) { where(ladies_only: true) if ladies.to_s == "true" }
  scope :filter_by_departure_date, ->(date_str) {
    if date_str.present?
      begin
        d = Date.parse(date_str.to_s)
        where(departure_time: d.beginning_of_day..d.end_of_day).or(where(departure_time: nil))
      rescue ArgumentError, TypeError
        all
      end
    end
  }

  scope :visible_to, ->(user) {
    if user.nil?
      publicly_visible
    else
      verified_ids = user.verified_community_ids

      conditions = [ sanitize_sql_for_conditions([ "ride_posts.user_id = ?", user.id ]) ]

      if user.female?
        conditions << sanitize_sql_for_conditions([ "ride_posts.visibility = 0" ])
      else
        conditions << sanitize_sql_for_conditions([ "ride_posts.visibility = 0 AND ride_posts.ladies_only = ?", false ])
      end

      if verified_ids.any?
        if user.female?
          conditions << sanitize_sql_for_conditions([ "ride_posts.visibility = 1 AND ride_posts.community_id IN (?)", verified_ids ])
        else
          conditions << sanitize_sql_for_conditions([ "ride_posts.visibility = 1 AND ride_posts.community_id IN (?) AND ride_posts.ladies_only = ?", verified_ids, false ])
        end
      end

      where(conditions.join(" OR "))
    end
  }

  scope :regular, -> { where(departure_time: nil) }
  scope :specific, -> { where.not(departure_time: nil) }
  scope :upcoming, -> { where("departure_time > ? OR departure_time IS NULL", Time.current) }

  def regular?
    departure_time.nil?
  end

  def to_param
    return id.to_s unless origin_id && destination_id

    unless association(:origin).loaded? && association(:destination).loaded?
      ActiveRecord::Associations::Preloader.new(records: [ self ], associations: [ :origin, :destination ]).call
    end

    return id.to_s unless origin && destination

    "#{id}-#{origin.name.parameterize}-to-#{destination.name.parameterize}"
  end

  def self.popular_routes(limit = 12)
    route_counts = publicly_visible.active.upcoming.group(:origin_id, :destination_id)
                         .order(Arel.sql("count(*) DESC"))
                         .limit(limit)
                         .count

    return [] if route_counts.empty?

    location_ids = route_counts.keys.flatten.uniq
    locations = Location.where(id: location_ids).index_by(&:id)

    route_counts.map do |(origin_id, destination_id), count|
      origin = locations[origin_id]
      destination = locations[destination_id]
      next unless origin && destination

      { origin: origin, destination: destination, count: count }
    end.compact
  end

  def published?
    active? || fulfilled?
  end

  def booking_cutoff_at
    departure_time
  end

  def automatic_completion_at
    return unless booking_cutoff_at

    expected_arrival_at ? [ expected_arrival_at + 2.hours, booking_cutoff_at ].max : booking_cutoff_at + 24.hours
  end

  def bookable?
    offering? && active? && remaining_seats.to_i > 0 && departure_time.present? && departure_time > Time.current
  end

  def full?
    offering? && (fulfilled? || remaining_seats.to_i <= 0)
  end

  def authorized_viewer?(viewer)
    return viewer.present? && user_id == viewer.id if draft?

    return false if viewer.blank? && (hub_only? || ladies_only?)
    return true if viewer.blank?

    return true if user_id == viewer.id

    if ladies_only? && !viewer.female?
      return false
    end

    if hub_only?
      return false unless viewer.verified_member_of?(community_id)
    end

    true
  end

  def authorized_for_booking?(passenger)
    return false unless passenger
    return false if user_id == passenger.id
    return false unless passenger.eligible_for_booking?

    authorized_viewer?(passenger)
  end

  def driver_eligible?
    return false unless user&.eligible_for_offering?
    return false if hub_only? && !user.verified_member_of?(community_id)
    return false if ladies_only? && !user.female?

    true
  end

  def chat_unlocked?
    bookings.accepted.exists?
  end

  def chat_writable?
    !canceled? && chat_unlocked? && (departure_time.blank? || Time.current <= departure_time + 24.hours)
  end

  def user_authorized_for_chat?(u)
    return false unless u
    return false if canceled?
    return false unless authorized_viewer?(u)

    if user_id == u.id
      u.banned_at.blank? && !u.deleted?
    else
      bookings.accepted.exists?(passenger_id: u.id) && u.banned_at.blank? && !u.deleted?
    end
  end

  def participants
    User.where(id: [ user_id ] + bookings.accepted.pluck(:passenger_id))
  end

  def participant?(u)
    return false unless u

    review_participants.exists?(id: u.id)
  end

  def reviewable_trip?
    offering? && !draft? && departure_time.present? && departure_time <= Time.current
  end

  def reviewable_by?(reviewer)
    reviewable_trip? && participant?(reviewer) && review_participants.where.not(id: reviewer.id).exists?
  end

  def review_participants
    participant_bookings = bookings.accepted
    if departure_time.present?
      late_cancellations = bookings.canceled.where("accepted_at <= ? AND canceled_at >= ?", departure_time, departure_time)
      participant_bookings = participant_bookings.or(late_cancellations)
    end
    User.where(id: user_id).or(User.where(id: participant_bookings.select(:passenger_id)))
  end

  def historical_reviewable_bookings
    dep_time = departure_time_was || departure_time
    return bookings.none if dep_time.blank?

    accepted_bookings = bookings.accepted
    late_cancellations = bookings.canceled.where("accepted_at <= ? AND canceled_at >= ?", dep_time, dep_time)
    accepted_bookings.or(late_cancellations)
  end

  def historical_reviewable_participation?
    dep_time = departure_time_was || departure_time
    return false if dep_time.blank? || dep_time > Time.current

    historical_reviewable_bookings.exists?
  end

  private

  def check_destruction_allowed
    if trip_reviews.exists? || no_show_incidents.exists?
      errors.add(:base, "Cannot delete a ride with trip reviews or incident history.")
      throw :abort
    end

    if bookings.accepted.exists?
      errors.add(:base, "Cannot delete a ride with accepted bookings. Please cancel the trip instead.")
      throw :abort
    end

    if historical_reviewable_participation?
      errors.add(:base, "Cannot delete a departed ride with historical participation. Trip records must be preserved for review eligibility.")
      throw :abort
    end

    bookings.pending.find_each do |b|
      Bookings::CancelService.call(b, actor: user)
    end
  end

  def initialize_remaining_seats
    self.remaining_seats ||= seats if offering? && seats.present?
  end

  def sync_remaining_seats_with_capacity
    if offering? && !bookings.accepted.exists? && will_save_change_to_seats?
      self.remaining_seats = seats
    end
  end

  def should_schedule_audit?
    offering? && published? && automatic_completion_at.present? && (saved_change_to_expected_arrival_at? || saved_change_to_departure_time? || saved_change_to_status?)
  end

  def schedule_trip_audit
    TripAuditJob.set(wait_until: automatic_completion_at).perform_later(id)
  end

  def publishing?
    new_record? || (will_save_change_to_status? && (status_before_last_save || status_was) == "draft")
  end

  def preload_locations
    unless association(:origin).loaded? && association(:destination).loaded?
      ActiveRecord::Associations::Preloader.new(records: [ self ], associations: [ :origin, :destination ]).call
    end
  end

  def route_must_have_distinct_locations
    errors.add(:destination, "must differ from origin") if origin_id.present? && origin_id == destination_id
  end

  def departure_time_cannot_be_in_the_past
    return if draft?
    return unless departure_time.present?
    return unless new_record? || will_save_change_to_departure_time?

    if departure_time < Time.current
      errors.add(:departure_time, "can't be in the past")
    end
  end

  def bookable_offering_requirements
    if departure_time.blank? || (publishing? && departure_time <= Time.current)
      errors.add(:departure_time, "is required for published ride offers")
    end

    if expected_arrival_at.present? && departure_time.present? && expected_arrival_at <= departure_time
      errors.add(:expected_arrival_at, "must be after departure time")
    end

    if remaining_seats.nil? || (publishing? && active? && remaining_seats <= 0)
      errors.add(:remaining_seats, "must be confirmed for published ride offers")
    end

    if user.present? && publishing? && !user.eligible_for_offering?
      errors.add(:user, "is not eligible to publish ride offers")
    end
  end

  def lock_attributes_when_accepted_bookings_exist
    has_accepted = bookings.accepted.exists?
    has_historical = historical_reviewable_participation?
    return unless has_accepted || has_historical

    locked_fields = %w[origin_id destination_id departure_time expected_arrival_at seats post_type visibility ladies_only community_id]
    changed_locked_fields = (changes.keys & locked_fields)

    if changed_locked_fields.any?
      if has_accepted
        errors.add(:base, "Cannot modify route, schedule, capacity, or audience while accepted bookings exist")
      else
        errors.add(:base, "Cannot modify route, schedule, capacity, or audience for trips with historical participation")
      end
    end

    if has_accepted && will_save_change_to_remaining_seats?
      max_allowed = [ seats - bookings.accepted.count, 0 ].max
      if remaining_seats > max_allowed
        errors.add(:remaining_seats, "cannot exceed available capacity (#{max_allowed}) while accepted bookings exist")
      end
    end
  end

  def driver_must_be_verified_community_member
    return unless user && community_id

    unless user.verified_member_of?(community_id)
      errors.add(:community, "requires an active verified membership")
    end
  end

  def driver_must_be_female_for_ladies_only
    return unless user

    unless user.female?
      errors.add(:ladies_only, "can only be offered by female drivers")
    end
  end
end
