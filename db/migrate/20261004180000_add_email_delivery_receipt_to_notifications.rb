class AddEmailDeliveryReceiptToNotifications < ActiveRecord::Migration[8.1]
  def change
    add_column :notifications, :email_delivered_at, :datetime
  end
end
