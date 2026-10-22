class CreateRideSchedules < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :ride_posts, "status = 4 OR (departure_date IS NOT NULL AND departure_choice IS NOT NULL)", name: "check_ride_posts_departure_presence"
    add_check_constraint :ride_posts, "status IN (2, 3, 4) OR (departure_date IS NOT NULL AND departure_choice IS NOT NULL)", name: "check_ride_posts_departure_presence"
    create_table :ride_schedules do |t|
      t.references :user, null: false, foreign_key: true
      t.references :origin, foreign_key: { to_table: :locations }
      t.references :destination, foreign_key: { to_table: :locations }
      t.references :community, foreign_key: true
      t.references :source_ride_post, foreign_key: { to_table: :ride_posts }, index: { unique: true }
      t.integer :status, default: 0, null: false
      t.integer :weekdays_mask, default: 0, null: false
      t.integer :departure_choice
      t.string :departure_clock
      t.integer :seats
      t.text :notes
      t.integer :visibility, default: 0, null: false
      t.boolean :ladies_only, default: false, null: false
      t.date :end_date
      t.timestamps
      t.check_constraint "weekdays_mask BETWEEN 0 AND 127", name: "check_ride_schedules_weekdays"
      t.check_constraint "seats IS NULL OR seats > 0", name: "check_ride_schedules_seats"
      t.check_constraint "status IN (0, 1, 2, 3)", name: "check_ride_schedules_status"
    end

    add_reference :ride_posts, :ride_schedule, foreign_key: true
    add_column :ride_posts, :schedule_date, :date
    add_index :ride_posts, [ :ride_schedule_id, :schedule_date ], unique: true
    add_check_constraint :ride_posts,
      "(ride_schedule_id IS NULL AND schedule_date IS NULL) OR (ride_schedule_id IS NOT NULL AND schedule_date IS NOT NULL AND schedule_date = departure_date)",
      name: "check_ride_posts_schedule_date"
  end
end
