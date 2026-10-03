class AllowIncompleteRideDrafts < ActiveRecord::Migration[8.1]
  def change
    change_column_null :ride_posts, :origin_id, true
    change_column_null :ride_posts, :destination_id, true
  end
end
