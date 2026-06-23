# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

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

# === 4. CREATE TEST USERS ===
puts "\nSeeding Users..."

users_data = [
  {
    email_address: "driver@example.com",
    first_name: "Juan (Driver)",
    last_name: "Dela Cruz",
    facebook_profile_url: "https://facebook.com/juan.delacruz",
    password: "password",
    admin: false
  },
  {
    email_address: "passenger@example.com",
    first_name: "Maria (Passenger)",
    last_name: "Clara",
    facebook_profile_url: "https://facebook.com/maria.clara",
    password: "password",
    admin: false
  },
  {
    email_address: "admin@example.com",
    first_name: "Juan (Admin)",
    last_name: "Dela Cruz",
    facebook_profile_url: "https://facebook.com/admin.delacruz",
    password: "password",
    admin: true
  }
]

seeded_users = users_data.map do |data|
  # Since admin is attr_readonly, we set it when initializing a new record
  user = User.find_or_initialize_by(email_address: data[:email_address])
  if user.new_record?
    user.assign_attributes(data)
    user.save!
    puts "Created user: #{data[:email_address]}"
  else
    puts "User already exists: #{data[:email_address]}"
  end
  user
end

driver = seeded_users.find { |u| u.email_address == "driver@example.com" }
passenger = seeded_users.find { |u| u.email_address == "passenger@example.com" }


# === 5. CREATE RIDE POSTS ===
puts "\nSeeding Ride Posts..."

manila = Location.find_by(name: "Manila")
quezon_city = Location.find_by(name: "Quezon City")
baguio = Location.find_by(name: "Baguio")

# Fallback if locations are not found
manila ||= Location.city.first
quezon_city ||= Location.city.second
baguio ||= Location.city.third

if manila && quezon_city
  # 1. Driver offers a regular ride (no departure time)
  driver.ride_posts.find_or_create_by!(
    origin: manila,
    destination: quezon_city,
    post_type: :offering,
    seats: 4,
    status: :active,
    notes: "I travel daily for work. Clean car, non-smokers preferred. Meetup at Taft Avenue."
  )

  # 2. Driver offers a specific ride (departure time in 3 days)
  driver.ride_posts.find_or_create_by!(
    origin: manila,
    destination: baguio || quezon_city,
    post_type: :offering,
    seats: 3,
    status: :active,
    departure_time: Time.current + 3.days,
    notes: "Weekend trip to Baguio! Sharing fuel costs. Max 1 bag per person."
  )

  # 3. Passenger requests a ride for tomorrow
  passenger.ride_posts.find_or_create_by!(
    origin: quezon_city,
    destination: manila,
    post_type: :requesting,
    seats: 1,
    status: :active,
    departure_time: Time.current + 1.day,
    notes: "Looking for a ride tomorrow morning. Willing to split toll and gas fees."
  )

  puts "Ride posts seeded successfully!"
else
  puts "Warning: Locations not found, skipping ride posts seeding."
end

puts "\nSeed complete!"
puts "Total Locations: #{Location.count}"
puts "Regions: #{Location.region.count}"
puts "Cities/Provinces: #{Location.city.count}"
puts "Total Users: #{User.count}"
puts "Total Ride Posts: #{RidePost.count}"
