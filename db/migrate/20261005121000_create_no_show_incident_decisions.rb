class CreateNoShowIncidentDecisions < ActiveRecord::Migration[8.1]
  def change
    add_column :no_show_incidents, :lock_version, :integer, default: 0, null: false

    create_table :no_show_incident_decisions do |t|
      t.references :no_show_incident, null: false, foreign_key: true
      t.references :reviewer, foreign_key: { to_table: :users, on_delete: :nullify }
      t.integer :previous_status
      t.integer :status, null: false
      t.text :reason
      t.datetime :booking_freeze_until
      t.boolean :legacy, default: false, null: false
      t.timestamps
    end

    reversible do |direction|
      direction.up do
        # Preserve the latest known console decision, without inventing its
        # previous outcome or a historical booking restriction.
        execute <<~SQL
          INSERT INTO no_show_incident_decisions
            (no_show_incident_id, reviewer_id, status, reason, legacy, created_at, updated_at)
          SELECT id, reviewer_id, status, decision_reason, #{connection.quote(true)}, resolved_at, resolved_at
          FROM no_show_incidents
          WHERE resolved_at IS NOT NULL
        SQL
      end
    end
  end
end
