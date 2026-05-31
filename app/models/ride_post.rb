class RidePost < ApplicationRecord
  belongs_to :user

  belongs_to :origin, class_name: "Location"
  belongs_to :destination, class_name: "Location"

  enum :post_type, { offering: 0, requesting: 1 }
  enum :status, { active: 0, fulfilled: 1, canceled: 2 }

  validates :departure_time, presence: true
  validates :seats, presence: true, numericality: { greater_than: 0 }
  validates :post_type, presence: true

end
