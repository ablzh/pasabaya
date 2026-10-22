class RemoveRidePostType < ActiveRecord::Migration[8.1]
  def up
    if select_value("SELECT COUNT(*) FROM ride_posts WHERE post_type IS NULL OR post_type != 0").to_i.positive?
      raise ActiveRecord::MigrationError, "Unexpected ride post types exist. Inspect them before migrating; no records have been relabeled or deleted."
    end

    remove_check_constraint :ride_posts, name: "check_ride_posts_driver_offers_only"
    remove_column :ride_posts, :post_type
  end

  def down
    add_column :ride_posts, :post_type, :integer, default: 0, null: false
    add_check_constraint :ride_posts, "post_type = 0", name: "check_ride_posts_driver_offers_only"
  end
end
