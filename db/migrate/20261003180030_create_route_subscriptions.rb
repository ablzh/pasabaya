# frozen_string_literal: true

class CreateRouteSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :route_subscriptions do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :origin, null: false, foreign_key: { to_table: :locations }, index: false
      t.references :destination, null: false, foreign_key: { to_table: :locations }
      t.date :departure_date
      t.references :community, foreign_key: { on_delete: :nullify }
      t.boolean :ladies_only, default: false, null: false
      t.integer :status, default: 0, null: false
      t.datetime :consumed_at
      t.references :ride_post, foreign_key: { on_delete: :nullify }

      t.timestamps
    end

    add_index :route_subscriptions, [ :origin_id, :destination_id, :status ]
    add_index :route_subscriptions,
              [ :user_id, :origin_id, :destination_id, :departure_date, :community_id, :ladies_only, :status ],
              name: "index_route_subscriptions_uniqueness",
              unique: true
  end
end
