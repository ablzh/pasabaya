# Required reference data is safe to replay in every environment.
# Demo accounts and rides require an explicit opt-in in development or test.

puts "Seeding Philippine Locations..."

# 1. Create the Country
philippines = Location.find_or_create_by!(
  name: "Philippines",
  location_type: :country,
  country_code: "PH"
)

# 2. Define the Regions and their respective Cities/Provinces
regions_data = {
  "National Capital Region (NCR)" => [
    "Caloocan", "Las Piñas", "Makati", "Malabon", "Mandaluyong", "Manila",
    "Marikina", "Muntinlupa", "Navotas", "Parañaque", "Pasay", "Pasig",
    "Quezon City", "San Juan", "Taguig", "Valenzuela", "Pateros"
  ],
  "Cordillera Administrative Region  (CAR)" => [
    "Abra", "Apayao", "Benguet", "Ifugao", "Kalinga", "Mountain Province", "Baguio"
  ],
  "Region I (Ilocos Region)" => [
    "Ilocos Norte", "Ilocos Sur", "La Union", "Pangasinan"
  ],
  "Region II (Cagayan Valley)" => [
    "Batanes", "Cagayan", "Isabela", "Nueva Vizcaya", "Quirino"
  ],
  "Region III (Central Luzon)" => [
    "Aurora", "Bataan", "Bulacan", "Nueva Ecija", "Pampanga", "Tarlac", "Zambales",
    "Angeles", "Olongapo"
  ],
  "Region IV-A (CALABARZON)" => [
    "Batangas", "Cavite", "Laguna", "Quezon", "Rizal", "Lucena"
  ],
  "MIMAROPA Region" => [
    "Marinduque", "Occidental Mindoro", "Oriental Mindoro", "Palawan", "Romblon",
    "Puerto Princesa"
  ],
  "Region V (Bicol Region)" => [
    "Albay", "Camarines Norte", "Camarines Sur", "Catanduanes", "Masbate", "Sorsogon"
  ],
  "Region VI (Western Visayas)" => [
    "Aklan", "Antique", "Capiz", "Guimaras", "Iloilo", "Iloilo"
  ],
  "Negros Island Region (NIR)" => [
    "Negros Occidental", "Negros Oriental", "Siquijor", "Bacolod"
  ],
  "Region VII (Central Visayas)" => [
    "Bohol", "Cebu", "City of Cebu", "Lapu-Lapu", "Mandaue"
  ],
  "Region VIII (Eastern Visayas)" => [
    "Biliran", "Eastern Samar", "Leyte", "Northern Samar", "Samar", "Southern Leyte",
    "Tacloban"
  ],
  "Region IX (Zamboanga Peninsula)" => [
    "Sulu", "Zamboanga del Norte", "Zamboanga del Sur", "Zamboanga Sibugay",
    "Isabela", "Zamboanga"
  ],
  "Region X (Northern Mindanao)" => [
    "Bukidnon", "Camiguin", "Lanao del Norte", "Misamis Occidental", "Misamis Oriental",
    "Cagayan de Oro", "Iligan"
  ],
  "Region XI (Davao Region)" => [
    "Davao de Oro", "Davao del Norte", "Davao del Sur", "Davao Occidental",
    "Davao Oriental", "Davao"
  ],
  "Region XII (SOCCSKSARGEN)" => [
    "Cotabato", "Sarangani", "South Cotabato", "Sultan Kudarat", "General Santos"
  ],
  "Region XIII (Caraga)" => [
    "Agusan del Norte", "Agusan del Sur", "Dinagat Islands", "Surigao del Norte",
    "Surigao del Sur", "Butuan"
  ],
  "Bangsamoro Autonomous Region in Muslim Mindanao (BARMM)" => [
    "Basilan", "Lanao del Sur", "Maguindanao del Norte", "Maguindanao del Sur",
    "Tawi-Tawi", "Special Geographic Area"
  ]
}

# 3. Iterate and Create Records
regions_data.each do |region_name, cities|
  # Create the Region
  region = Location.find_or_create_by!(
    name: region_name,
    location_type: :region,
    parent: philippines,
    country_code: "PH"
  )

  # Create the Cities/Provinces under this Region
  cities.each do |city_name|
    Location.find_or_create_by!(
      name: city_name,
      location_type: :city,
      parent: region,
      country_code: "PH"
    )
  end
end

puts "\nSeeding Curated Communities..."
up = Community.find_or_initialize_by(domain: "up.edu.ph")
up.assign_attributes(name: "University of the Philippines", slug: "university-of-the-philippines", hub_type: :campus)
up.save!

if ENV["SEED_DEMO"] == "1" && (Rails.env.development? || Rails.env.test?)
  load Rails.root.join("db/seeds/demo.rb")
end

puts "\nReference seed complete!"
puts "Total Locations: #{Location.count}"
puts "Total Communities: #{Community.count}"
