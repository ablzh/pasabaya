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
      .transform_values { |cities| cities.map { |city| [ city.name, city.id ] } }
  end

  before_validation :generate_slug, if: -> { slug.blank? || name_changed? }

  # Basic validations
  validates :name, presence: true
  validates :location_type, presence: true
  validates :slug, presence: true, uniqueness: { case_sensitive: false }

  def self.find_by_slug(slug)
    city.find_by(slug: slug&.downcase)
  end

  private
  def generate_slug
    return if name.blank?

    base_slug = name.parameterize
    self.slug = base_slug

    # Если слаг уже занят ДРУГОЙ локацией, пробуем добавить регион/родителя
    if Location.where.not(id: id).exists?(slug: slug) && parent.present?
      self.slug = "#{base_slug}-#{parent.name.parameterize}"
    end

    # Если всё еще занят (на всякий случай), добавляем суффикс
    suffix = 1
    final_slug = self.slug
    while Location.where.not(id: id).exists?(slug: final_slug)
      final_slug = "#{self.slug}-#{suffix}"
      suffix += 1
    end

    self.slug = final_slug
  end
end
