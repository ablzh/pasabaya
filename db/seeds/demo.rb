# Local demo data is never permitted in production or staging, even if loaded directly.
raise "Demo seeds require development or test" unless Rails.env.development? || Rails.env.test?

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

up = Community.find_by!(domain: "up.edu.ph")

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
