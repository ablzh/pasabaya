class RidePost < ApplicationRecord
  belongs_to :user

  belongs_to :origin, class_name: "Location"
  belongs_to :destination, class_name: "Location"

  enum :post_type, { offering: 0, requesting: 1 }
  enum :status, { active: 0, fulfilled: 1, canceled: 2 }

  validate :departure_time_cannot_be_in_the_past
  validates :seats, presence: true, numericality: { greater_than: 0 }
  validates :post_type, presence: true

  scope :filter_by_post_type, ->(type) { where(post_type: type) if type.present? }
  scope :filter_by_origin, ->(origin_id) { where(origin_id: origin_id) if origin_id.present? }
  scope :filter_by_destination, ->(destination_id) { where(destination_id: destination_id)  if destination_id.present? }

  scope :regular, -> { where(departure_time: nil) }
  scope :specific, -> { where.not(departure_time: nil) }

  def regular?
    departure_time.nil?
  end

  def to_param
    return id.to_s unless origin && destination

    "#{id}-#{origin.name.parameterize}-to-#{destination.name.parameterize}"
  end

  def self.popular_routes(limit = 12)
    route_counts = active.group(:origin_id, :destination_id)
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

  private
  def departure_time_cannot_be_in_the_past
    if departure_time.present? && departure_time < Time.current
      errors.add(:departure_time, "can't be in the past")
    end
  end
end
