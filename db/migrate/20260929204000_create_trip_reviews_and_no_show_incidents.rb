class CreateTripReviewsAndNoShowIncidents < ActiveRecord::Migration[8.1]
  def change
    create_table :trip_reviews do |t|
      t.references :ride_post, null: false, foreign_key: true, index: false
      t.references :reporter, null: false, foreign_key: { to_table: :users }, index: true
      t.references :reported_user, null: false, foreign_key: { to_table: :users }, index: true
      t.integer :outcome, default: 0, null: false
      t.text :notes

      t.timestamps
    end

    add_index :trip_reviews, [ :ride_post_id, :reporter_id, :reported_user_id ],
              unique: true, name: "index_trip_reviews_unique_per_participant"

    create_table :no_show_incidents do |t|
      t.references :ride_post, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true, index: true
      t.references :reviewer, foreign_key: { to_table: :users, on_delete: :nullify }, index: true
      t.integer :status, default: 0, null: false
      t.datetime :occurred_at, null: false
      t.datetime :resolved_at
      t.text :decision_reason

      t.timestamps
    end

    add_index :no_show_incidents, [ :ride_post_id, :user_id ],
              unique: true, name: "index_no_show_incidents_unique_per_trip_user"
  end
end
