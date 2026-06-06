class Location < ApplicationRecord
  has_many :departing_rides, class_name: "RidePost", foreign_key: "origin_id"
  has_many :arriving_rides, class_name: "RidePost", foreign_key: "destination_id"

  # Define the hierarchy levels.
  # Rails will map these to integers (0, 1, 2) in the database.
  enum :location_type, { country: 0, region: 1, city: 2 }

  # A location belongs to a parent location (optional, as countries have no parent).
  belongs_to :parent, class_name: "Location", optional: true

  # A location can have many child locations.
  # We specify the foreign_key so Rails knows how to find them.
  has_many :children, class_name: "Location", foreign_key: "parent_id", dependent: :destroy

  # Sorting the city list
  default_scope { order(name: :asc) }

  # Returns cities grouped by region, sorted alphabetically by region and city name.
  def self.grouped_by_region
    city
      .includes(:parent)
      .reorder("parents_locations.name ASC, locations.name ASC")
      .group_by { |city| city.parent&.name || "Other" }
      .transform_values { |cities| cities.map { |city| [city.name, city.id] } }
  end

  # Basic validations
  validates :name, presence: true
  validates :location_type, presence: true
end
