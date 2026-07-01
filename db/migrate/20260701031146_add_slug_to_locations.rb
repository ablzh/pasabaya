class AddSlugToLocations < ActiveRecord::Migration[8.1]
  def change
    add_column :locations, :slug, :string

    reversible do |dir|
      dir.up do
        Location.reset_column_information
        Location.find_each do |location|
          location.save!
        end
      end
    end

    add_index :locations, :slug, unique: true
  end
end
