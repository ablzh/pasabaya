class CreateRidePosts < ActiveRecord::Migration[8.1]
  def change
    create_table :ride_posts do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :post_type
      t.references :origin, null: false, foreign_key: { to_table: :locations }
      t.references :destination, null: false, foreign_key: { to_table: :locations }
      t.datetime :departure_time
      t.integer :seats
      t.text :notes
      t.integer :status, default: 0, null: false

      t.timestamps
    end
  end
end
