# frozen_string_literal: true

class AddRouteSubscriptionToNotifications < ActiveRecord::Migration[8.1]
  def change
    add_reference :notifications, :route_subscription, foreign_key: { on_delete: :nullify }

    reversible do |direction|
      direction.up do
        execute <<~SQL
          UPDATE notifications
          SET route_subscription_id = (
            SELECT route_subscriptions.id
            FROM route_subscriptions
            WHERE notifications.delivery_key = 'route_alert:' || route_subscriptions.id || ':' || notifications.notifiable_id
          )
          WHERE event_name = 'route.alert' AND notifiable_type = 'RidePost'
        SQL
      end
    end
  end
end
