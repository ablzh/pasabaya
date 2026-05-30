class CreateLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :locations do |t|
      t.string :name
      t.integer :location_type
      t.references :parent, null: false, foreign_key: true
      t.string :country_code

      t.timestamps
    end
  end
end
