class CreateBookings < ActiveRecord::Migration[8.1]
  def change
    create_table :bookings do |t|
      t.references :ride_post, null: false, foreign_key: true, index: false
      t.references :passenger, null: false, foreign_key: { to_table: :users }, index: false
      t.integer :status, default: 0, null: false
      t.text :pickup_notes
      t.datetime :decided_at
      t.datetime :canceled_at
      t.references :canceled_by, foreign_key: { to_table: :users, on_delete: :nullify }

      t.timestamps
    end

    add_index :bookings, [ :ride_post_id, :passenger_id ],
              unique: true,
              where: "status IN (0, 1)",
              name: "index_bookings_on_ride_and_passenger_active"
    add_index :bookings, [ :passenger_id, :status ]
    add_index :bookings, [ :ride_post_id, :status ]
  end
end
