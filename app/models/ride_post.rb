class RidePost < ApplicationRecord
  belongs_to :user
  belongs_to :origin
  belongs_to :destination
end
