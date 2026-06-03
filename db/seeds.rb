# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# 1. Create the Country
philippines = Location.find_or_create_by!(
  name: "Philippines",
  location_type: :country,
  country_code: "PH"
)

# 2. Create Regions
regions = [
  { name: "Metro Manila", location_type: :region, parent: philippines },
  { name: "Central Visayas", location_type: :region, parent: philippines },
  { name: "Davao Region", location_type: :region, parent: philippines }
]

regions.each do |region_data|
  Location.find_or_create_by!(region_data)
end

# 3. Create Key Cities
cities = [
# Metro Manila Cities
{ name: "Manila", location_type: :city, parent: Location.find_by(name: "Metro Manila") },
{ name: "Quezon City", location_type: :city, parent: Location.find_by(name: "Metro Manila") },
{ name: "Makati", location_type: :city, parent: Location.find_by(name: "Metro Manila") },

# Central Visayas Cities
{ name: "Cebu City", location_type: :city, parent: Location.find_by(name: "Central Visayas") },
{ name: "Mandaue City", location_type: :city, parent: Location.find_by(name: "Central Visayas") },

# Davao Region Cities
{ name: "Davao City", location_type: :city, parent: Location.find_by(name: "Davao Region") }
]

cities.each do |city_data|
  Location.find_or_create_by!(city_data)
  end

puts "Seeded #{Location.count} locations."
