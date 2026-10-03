# frozen_string_literal: true

class CreateAccountDeletionTombstones < ActiveRecord::Migration[8.0]
  def change
    create_table :account_deletion_tombstones do |t|
      t.integer :user_id, null: false
      t.string :anonymized_email, null: false
      t.datetime :deleted_at, null: false

      t.timestamps
    end
    add_index :account_deletion_tombstones, :user_id, unique: true
  end
end
