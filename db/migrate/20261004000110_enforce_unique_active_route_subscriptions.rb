# frozen_string_literal: true

class EnforceUniqueActiveRouteSubscriptions < ActiveRecord::Migration[8.1]
  def up
    remove_index :route_subscriptions, name: "index_route_subscriptions_uniqueness"

    # Keep the oldest subscription if nullable filters allowed duplicate active rows.
    execute <<~SQL
      UPDATE route_subscriptions
      SET status = 2, updated_at = CURRENT_TIMESTAMP
      WHERE status = 0 AND EXISTS (
        SELECT 1 FROM route_subscriptions AS earlier
        WHERE earlier.status = 0 AND earlier.id < route_subscriptions.id
          AND earlier.user_id = route_subscriptions.user_id
          AND earlier.origin_id = route_subscriptions.origin_id
          AND earlier.destination_id = route_subscriptions.destination_id
          AND COALESCE(earlier.departure_date, '') = COALESCE(route_subscriptions.departure_date, '')
          AND COALESCE(earlier.community_id, 0) = COALESCE(route_subscriptions.community_id, 0)
          AND earlier.ladies_only = route_subscriptions.ladies_only
      )
    SQL

    add_index :route_subscriptions,
              "user_id, origin_id, destination_id, COALESCE(departure_date, ''), COALESCE(community_id, 0), ladies_only",
              where: "status = 0", unique: true,
              name: "index_route_subscriptions_active_uniqueness"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Route subscription history can now contain repeated search filters"
  end
end
