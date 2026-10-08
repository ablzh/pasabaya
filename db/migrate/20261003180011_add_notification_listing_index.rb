class AddNotificationListingIndex < ActiveRecord::Migration[8.1]
  def change
    add_index :notifications, [ :recipient_id, :created_at ]
  end
end
