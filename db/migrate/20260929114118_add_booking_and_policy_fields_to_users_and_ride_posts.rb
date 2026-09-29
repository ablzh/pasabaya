class AddBookingAndPolicyFieldsToUsersAndRidePosts < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :gender, :integer, default: 0, null: false
    add_column :users, :booking_freeze_until, :datetime

    add_column :ride_posts, :expected_arrival_at, :datetime
    add_column :ride_posts, :remaining_seats, :integer
    add_column :ride_posts, :visibility, :integer, default: 0, null: false
    add_column :ride_posts, :community_id, :integer
    add_column :ride_posts, :ladies_only, :boolean, default: false, null: false
    add_column :ride_posts, :share_tolls, :boolean, default: false, null: false
    add_column :ride_posts, :split_gas, :boolean, default: false, null: false
    add_column :ride_posts, :is_free_ride, :boolean, default: false, null: false

    add_index :ride_posts, :community_id

    add_check_constraint :ride_posts, "seats > 0", name: "check_ride_posts_seats_positive"
    add_check_constraint :ride_posts, "NOT (is_free_ride = 1 AND (share_tolls = 1 OR split_gas = 1))", name: "check_ride_posts_cost_sharing"
    add_check_constraint :ride_posts, "post_type != 0 OR remaining_seats IS NULL OR (remaining_seats >= 0 AND remaining_seats <= seats)", name: "check_ride_posts_offering_inventory"

    reversible do |dir|
      dir.up do
        # Transition existing active offers into draft (status: 4) to require reconfirmation before booking
        execute <<-SQL
          UPDATE ride_posts
          SET status = 4
          WHERE post_type = 0 AND status = 0;
        SQL
      end
    end
  end
end
