class RequireDriverOffers < ActiveRecord::Migration[8.1]
  def up
    if select_value("SELECT COUNT(*) FROM ride_posts WHERE post_type IS NULL OR post_type != 0").to_i.positive?
      raise ActiveRecord::MigrationError, "Unexpected passenger-request ride posts exist. Inspect them before migrating; no records have been relabeled or deleted."
    end

    change_column_default :ride_posts, :post_type, from: nil, to: 0
    change_column_null :ride_posts, :post_type, false
    change_column_null :ride_posts, :seats, false
    add_check_constraint :ride_posts, "post_type = 0", name: "check_ride_posts_driver_offers_only"
    remove_check_constraint :ride_posts, name: "check_ride_posts_offering_inventory"
    add_check_constraint :ride_posts, "remaining_seats IS NULL OR (remaining_seats >= 0 AND remaining_seats <= seats)", name: "check_ride_posts_offering_inventory"
  end

  def down
    remove_check_constraint :ride_posts, name: "check_ride_posts_driver_offers_only"
    remove_check_constraint :ride_posts, name: "check_ride_posts_offering_inventory"
    add_check_constraint :ride_posts, "post_type != 0 OR remaining_seats IS NULL OR (remaining_seats >= 0 AND remaining_seats <= seats)", name: "check_ride_posts_offering_inventory"
    change_column_null :ride_posts, :seats, true
    change_column_null :ride_posts, :post_type, true
    change_column_default :ride_posts, :post_type, from: 0, to: nil
  end
end
