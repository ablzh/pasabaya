class AddAcceptedAtToBookings < ActiveRecord::Migration[8.1]
  def up
    add_column :bookings, :accepted_at, :datetime
    execute <<~SQL
      UPDATE bookings
      SET accepted_at = COALESCE(decided_at, created_at)
      WHERE status = 1 OR (status = 3 AND decided_at IS NOT NULL)
    SQL
  end

  def down
    remove_column :bookings, :accepted_at
  end
end
