class RemoveRetiredRideCostSharing < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :ride_posts, "NOT (is_free_ride = 1 AND (share_tolls = 1 OR split_gas = 1))", name: "check_ride_posts_cost_sharing"
    remove_columns :ride_posts, :is_free_ride, :share_tolls, :split_gas, type: :boolean, default: false, null: false
  end
end
