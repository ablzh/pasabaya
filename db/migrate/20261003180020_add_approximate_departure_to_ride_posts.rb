class AddApproximateDepartureToRidePosts < ActiveRecord::Migration[8.1]
  def up
    add_column :ride_posts, :departure_date, :date
    add_column :ride_posts, :departure_choice, :integer

    add_index :ride_posts, [ :departure_date, :departure_choice ]

    execute <<-SQL.squish
      UPDATE ride_posts
      SET departure_date = DATE(departure_time),
          departure_choice = 4
      WHERE departure_time IS NOT NULL;
    SQL

    add_check_constraint :ride_posts, "status = 4 OR (departure_date IS NOT NULL AND departure_choice IS NOT NULL)", name: "check_ride_posts_departure_presence"
  end

  def down
    remove_check_constraint :ride_posts, name: "check_ride_posts_departure_presence"
    remove_index :ride_posts, [ :departure_date, :departure_choice ]
    remove_column :ride_posts, :departure_choice
    remove_column :ride_posts, :departure_date
  end
end
