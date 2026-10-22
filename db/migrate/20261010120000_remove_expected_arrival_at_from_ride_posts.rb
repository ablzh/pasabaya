class RemoveExpectedArrivalAtFromRidePosts < ActiveRecord::Migration[8.1]
  def change
    remove_column :ride_posts, :expected_arrival_at, :datetime
  end
end
