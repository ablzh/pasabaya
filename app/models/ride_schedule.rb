class RideSchedule < ApplicationRecord
  BOOKING_DAYS = 14
  WEEKDAYS = [ [ "Monday", 1 ], [ "Tuesday", 2 ], [ "Wednesday", 3 ], [ "Thursday", 4 ], [ "Friday", 5 ], [ "Saturday", 6 ], [ "Sunday", 0 ] ].freeze
  OFFER_FIELDS = %w[user_id origin_id destination_id community_id seats notes visibility ladies_only departure_choice].freeze

  belongs_to :user
  belongs_to :origin, class_name: "Location", optional: true
  belongs_to :destination, class_name: "Location", optional: true
  belongs_to :community, optional: true
  belongs_to :source_ride_post, class_name: "RidePost", optional: true
  has_many :ride_posts, dependent: :restrict_with_error

  enum :status, { draft: 0, active: 1, paused: 2, archived: 3 }, default: :draft, validate: true
  enum :visibility, { public_ride: 0, hub_only: 1 }, default: :public_ride, validate: true
  enum :departure_choice, RidePost.departure_choices, validate: { allow_nil: true }

  before_validation :preload_locations

  validates :origin, :destination, :seats, :departure_choice, presence: true, unless: :draft?
  validates :seats, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :notes, length: { maximum: 300 }
  validates :ladies_only, inclusion: { in: [ true, false ] }
  validates :weekdays_mask, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 128 }
  validates :source_ride_post_id, uniqueness: true, allow_nil: true
  validate :valid_schedule

  def weekday_ids
    (0..6).select { |day| weekdays_mask.to_i[day] == 1 }
  end

  def weekday_ids=(values)
    days = Array(values).reject(&:blank?).map(&:to_s)
    @invalid_weekdays = days.any? { |day| !day.match?(/\A[0-6]\z/) }
    self.weekdays_mask = days.select { |day| day.match?(/\A[0-6]\z/) }.uniq.sum { |day| 1 << day.to_i }
  end

  def schedule_display
    days = WEEKDAYS.filter_map { |label, day| label.first(3) if weekday_ids.include?(day) }.join(", ")
    time = exact_time? ? departure_clock : departure_choice&.humanize
    [ days.presence, time.presence ].compact.join(" • ")
  end

  def ride_attributes(date)
    attributes.slice(*OFFER_FIELDS).merge(
      departure_date: date, departure_time: exact_time? && departure_clock.present? ? date.in_time_zone("Asia/Manila").change(hour: departure_clock[0, 2].to_i, min: departure_clock[3, 2].to_i) : nil,
      status: :active, remaining_seats: seats
    )
  end

  def authorized_viewer?(viewer)
    return viewer&.id == user_id if draft?

    RidePost.new(attributes.slice(*OFFER_FIELDS)).authorized_viewer?(viewer)
  end

  def driver_eligible?
    RidePost.new(attributes.slice(*OFFER_FIELDS).merge(user: user)).driver_eligible?
  end

  def accepts_requests_for?(date)
    active? && date.present? && date.between?(Date.current, Date.current + BOOKING_DAYS - 1) && driver_eligible?
  end

  def generation_dates
    return [] unless active?

    (Date.current...(Date.current + BOOKING_DAYS)).select do |date|
      weekday_ids.include?(date.wday) && (end_date.nil? || date <= end_date)
    end
  end

  private

  def preload_locations
    ActiveRecord::Associations::Preloader.new(records: [ self ], associations: [ :origin, :destination ]).call
  end

  def valid_schedule
    errors.add(:weekday_ids, "must contain valid days of the week") if @invalid_weekdays
    return if draft?

    errors.add(:weekday_ids, "must include at least one day") if weekdays_mask.to_i.zero?
    errors.add(:destination, "must differ from origin") if origin_id.present? && origin_id == destination_id
    errors.add(:departure_clock, "must be a valid time (HH:MM)") if exact_time? && !departure_clock.to_s.match?(/\A(?:[01]\d|2[0-3]):[0-5]\d\z/)
    errors.add(:community, "is required for a hub-only schedule") if hub_only? && community.nil?
    if active?
      self.user = User.lock.find_by(id: user_id)
      errors.add(:user, "is not eligible to publish this schedule") unless driver_eligible?
      errors.add(:ladies_only, "can only be offered by female drivers") if ladies_only? && !user&.female?
      if hub_only? && community_id.present? && !user&.verified_member_of?(community_id)
        errors.add(:community, "requires an active verified membership")
      end
      if end_date.present? && end_date < Date.current && (new_record? || will_save_change_to_end_date? || will_save_change_to_status?)
        errors.add(:end_date, "cannot be in the past")
      end
    end
  end
end
