class CorrectExactDepartureDates < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE ride_posts
      SET departure_date = DATE(departure_time, '+8 hours')
      WHERE departure_choice = 4 AND departure_time IS NOT NULL;
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "The selected Philippine date must remain consistent with the exact departure."
  end
end
