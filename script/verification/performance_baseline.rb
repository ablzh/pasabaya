# frozen_string_literal: true

require_relative "support"

Verification.run do
  driver = Verification.user("driver")
  passenger = Verification.user("passenger")
  origin = Location.create!(name: "Synthetic origin", location_type: :city)
  destination = Location.create!(name: "Synthetic destination", location_type: :city)
  ride = RidePost.create!(user: driver, origin: origin, destination: destination, seats: 3, status: :active, departure_time: 1.day.from_now)
  sessions = [ driver, passenger ].map do |user|
    session = ActionDispatch::Integration::Session.new(Rails.application)
    session.post("/session", params: { email_address: user.email_address, password: "synthetic-password" })
    Verification.check(session.response.redirect?, "Sign in failed")
    session
  end
  results = []
  previous_size = 0
  [ 200, 2000 ].each do |size|
    attributes = ride.attributes.except("id").merge("status" => RidePost.statuses[:completed], "departure_time" => 4.days.ago,
      "departure_date" => 4.days.ago.to_date, "created_at" => 5.days.ago.change(usec: 0))
    ids = RidePost.insert_all!(Array.new(size - previous_size) { attributes.dup }, returning: %w[id]).rows.flatten
    Booking.insert_all!(ids.map { |id| { ride_post_id: id, passenger_id: passenger.id, status: Booking.statuses[:accepted], accepted_at: 5.days.ago, created_at: 5.days.ago, updated_at: 5.days.ago } })
    previous_size = size
    [ [ "driver_history", sessions.first, "/trips" ], [ "joined_history", sessions.last, "/trips?tab=bookings" ] ].each do |name, session, path|
      3.times { session.get(path) }
      samples = 20.times.map do
        queries = records = 0
        sql = ->(_name, _start, _finish, _id, payload) { queries += 1 unless payload[:name] == "SCHEMA" || payload[:cached] || payload[:sql].match?(/\A(?:BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/) }
        instantiation = ->(_name, _start, _finish, _id, payload) { records += payload[:record_count] if payload[:class_name] == "RidePost" }
        started = Verification.clock
        ActiveSupport::Notifications.subscribed(sql, "sql.active_record") do
          ActiveSupport::Notifications.subscribed(instantiation, "instantiation.active_record") { session.get(path) }
        end
        duration = (Verification.clock - started) * 1000
        Verification.check(session.response.status == 200, "History request failed")
        Verification.check(records <= 21, "History loaded more than a page")
        { milliseconds: duration, sql_queries: queries, ride_posts_instantiated: records, response_bytes: session.response.body.bytesize }
      end
      times = samples.map { |sample| sample[:milliseconds] }.sort
      results << { workload: name, historical_rides: size, bookings: size, warmups: 3, requests: samples.size,
        median_ms: ((times[9] + times[10]) / 2).round(2), p95_ms: times[18].round(2),
        sql_queries: samples.map { |sample| sample[:sql_queries] }.minmax,
        ride_posts_instantiated: samples.map { |sample| sample[:ride_posts_instantiated] }.minmax,
        response_bytes: samples.map { |sample| sample[:response_bytes] }.minmax }
    end
  end
  puts JSON.generate(workflow: "performance_baseline", recorded_at: Time.current.utc.iso8601,
    environment: Verification.environment, data: "synthetic only", measurements: results)
end
