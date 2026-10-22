class CreateRidePostDispatches < ActiveRecord::Migration[8.1]
  def change
    create_table :ride_post_dispatches do |t|
      t.references :ride_post, null: false, foreign_key: { on_delete: :cascade }
      t.string :operation, null: false
      t.json :recipient_ids, null: false, default: []
      t.integer :failure_count, null: false, default: 0
      t.string :last_error
      t.datetime :failed_at

      t.timestamps
    end
  end
end
