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
    admin: false,
    gender: :male
  },
  {
    email_address: "passenger@example.com",
    first_name: "Maria (Passenger)",
    last_name: "Clara",
    facebook_profile_url: "https://facebook.com/maria.clara",
    password: "password",
    admin: false,
    gender: :female
  },
  {
    email_address: "admin@example.com",
    first_name: "Juan (Admin)",
    last_name: "Dela Cruz",
    facebook_profile_url: "https://facebook.com/admin.delacruz",
    password: "password",
    admin: true,
    gender: :male
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
    user.update!(gender: data[:gender]) if data[:gender].present?
    puts "User already exists: #{data[:email_address]}"
  end
  user
end

driver = seeded_users.find { |u| u.email_address == "driver@example.com" }
passenger = seeded_users.find { |u| u.email_address == "passenger@example.com" }

# === 4.5 CREATE CURATED COMMUNITIES ===
puts "\nSeeding Curated Communities..."

# Retain only University of the Philippines, removing unwanted local hubs safely
Community.where.not(domain: "up.edu.ph").find_each do |c|
  c.ride_posts.destroy_all
  c.route_subscriptions.destroy_all
  c.community_memberships.destroy_all
  c.destroy!
end

up = Community.find_or_initialize_by(domain: "up.edu.ph")
up.name = "University of the Philippines"
up.slug = "university-of-the-philippines"
up.hub_type = :campus
up.save!

CommunityMembership.find_or_create_by!(user: passenger, community: up) do |m|
  m.institutional_email = "maria.clara@up.edu.ph"
  m.verified_at = Time.current
end

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
  # 1. Driver has an unconfirmed draft offer (awaiting reconfirmation)
  driver.ride_posts.find_or_create_by!(
    origin: manila,
    destination: quezon_city,
    post_type: :offering,
    seats: 4,
    status: :draft,
    notes: "I travel daily for work. Clean car, non-smokers preferred. Meetup at Taft Avenue."
  )

  # 2. A stable lookup keeps repeated seeds from creating dated duplicates.
  driver.ride_posts.find_or_create_by!(notes: "Weekend trip to Baguio! Sharing fuel costs. Max 1 bag per person.") do |ride|
    ride.origin = manila
    ride.destination = baguio || quezon_city
    ride.seats = 3
    ride.remaining_seats = 3
    ride.status = :active
    ride.departure_time = 3.days.from_now
    ride.expected_arrival_at = ride.departure_time + 5.hours
    ride.split_gas = true
  end

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
