class AddUnsubscribedAtToSubscribers < ActiveRecord::Migration[8.1]
  def change
    add_column :subscribers, :unsubscribed_at, :datetime
  end
end
