class CreateRidePosts < ActiveRecord::Migration[8.1]
  def change
    create_table :ride_posts do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :post_type
      t.references :origin, null: false, foreign_key: true
      t.references :destination, null: false, foreign_key: true
      t.datetime :departure_time
      t.integer :seats
      t.text :notes
      t.integer :status

      t.timestamps
    end
  end
end
