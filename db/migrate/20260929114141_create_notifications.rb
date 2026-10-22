class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :recipient, null: false, foreign_key: { to_table: :users }, index: false
      t.references :actor, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :notifiable, polymorphic: true, null: false
      t.string :event_name, null: false
      t.string :delivery_key, null: false
      t.integer :delivery_status, default: 0, null: false
      t.datetime :delivered_at
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, :delivery_key, unique: true
    add_index :notifications, [ :recipient_id, :read_at ]
  end
end
