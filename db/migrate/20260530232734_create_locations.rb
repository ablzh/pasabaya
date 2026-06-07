class CreateLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :locations do |t|
      t.string :name
      t.integer :location_type
      t.references :parent, null: true, foreign_key: { to_table: :locations }
      t.string :country_code

      t.timestamps
    end
  end
end
