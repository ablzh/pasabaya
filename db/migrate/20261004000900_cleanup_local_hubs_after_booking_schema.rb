class CleanupLocalHubsAfterBookingSchema < ActiveRecord::Migration[8.1]
  def up
    Community.cleanup_disposable_local_hubs!
  end

  def down
    # Disposable local data cannot be restored by a rollback.
  end
end
