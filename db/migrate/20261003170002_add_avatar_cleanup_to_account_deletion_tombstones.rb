class AddAvatarCleanupToAccountDeletionTombstones < ActiveRecord::Migration[8.1]
  def change
    add_column :account_deletion_tombstones, :avatar_blob_id, :bigint
    add_column :account_deletion_tombstones, :avatar_key, :string
    add_column :account_deletion_tombstones, :avatar_service_name, :string
  end
end
