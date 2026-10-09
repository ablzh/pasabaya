class AddApproximateDepartureToRidePosts < ActiveRecord::Migration[8.1]
  def up
    add_column :ride_posts, :departure_date, :date
    add_column :ride_posts, :departure_choice, :integer

    add_index :ride_posts, [ :departure_date, :departure_choice ]

    execute <<-SQL.squish
      UPDATE ride_posts
      SET departure_date = DATE(departure_time, '+8 hours'),
          departure_choice = 4
      WHERE departure_time IS NOT NULL;
    SQL

    # Before booking existed, fulfilled meant a finished offer. Preserve undated
    # legacy history as completed rather than inventing a departure date.
    execute <<-SQL.squish
      UPDATE ride_posts SET status = 3
      WHERE status = 1 AND departure_time IS NULL
        AND NOT EXISTS (SELECT 1 FROM bookings WHERE bookings.ride_post_id = ride_posts.id);
    SQL

    add_check_constraint :ride_posts, "status IN (2, 3, 4) OR (departure_date IS NOT NULL AND departure_choice IS NOT NULL)", name: "check_ride_posts_departure_presence"
  end

  def down
    remove_check_constraint :ride_posts, name: "check_ride_posts_departure_presence"
    remove_index :ride_posts, [ :departure_date, :departure_choice ]
    remove_column :ride_posts, :departure_choice
    remove_column :ride_posts, :departure_date
  end
end
