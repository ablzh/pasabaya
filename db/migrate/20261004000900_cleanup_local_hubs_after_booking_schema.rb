class CleanupLocalHubsAfterBookingSchema < ActiveRecord::Migration[8.1]
  def up
    Community.cleanup_disposable_local_hubs!
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Deleted disposable local hubs and their dependent records cannot be restored."
  end
end
