require "test_helper"
require "open3"

module Bookings
  class ConcurrentAcceptanceTest < ActiveSupport::TestCase
    test "simultaneous requests for the final seat confirm only one passenger" do
      Dir.mktmpdir("pasabaya-final-seat-") do |directory|
        script = File.join(directory, "race.rb")
        File.write(script, <<~'RUBY')
          require "timeout"
          ActiveRecord::Schema.verbose = false
          load Rails.root.join("db/schema.rb")
          driver = User.create!(email_address: "driver@example.com", password: "password", first_name: "Driver", last_name: "One")
          origin = Location.create!(name: "Origin", location_type: :city)
          destination = Location.create!(name: "Destination", location_type: :city)
          ride = RidePost.create!(user: driver, origin: origin, destination: destination, seats: 1, status: :active, departure_time: 1.day.from_now)
          bookings = 2.times.map do |index|
            passenger = User.create!(email_address: "passenger#{index}@example.com", password: "password", first_name: "Passenger", last_name: index.to_s)
            Booking.create!(ride_post: ride, passenger: passenger)
          end
          Bookings::AcceptService
          ready = Queue.new
          start = Queue.new
          workers = bookings.map do |booking|
            Thread.new do
              Rails.application.executor.wrap do
                ActiveRecord::Base.connection_pool.with_connection do
                  target = Booking.find(booking.id)
                  actor = User.find(driver.id)
                  ready << true
                  start.pop
                  begin
                    Bookings::AcceptService.call(target, actor: actor)
                    :accepted
                  rescue Bookings::AcceptService::CapacityError
                    :full
                  end
                end
              end
            end
          end
          Timeout.timeout(15) do
            2.times { ready.pop }
            2.times { start << true }
            results = workers.map(&:value)
            raise "Both contenders must finish with one accepted passenger: #{results.inspect}" unless results.sort == [:accepted, :full]
          end
          raise "Seat inventory is incorrect" unless ride.reload.remaining_seats.zero? && ride.fulfilled?
          raise "Exactly one booking must be accepted" unless ride.bookings.accepted.count == 1 && ride.bookings.pending.count == 1
          raise "Exactly one acceptance event must be recorded" unless Notification.where(event_name: "booking.accepted").count == 1
        RUBY
        output, status = Open3.capture2e(
          { "DATABASE_URL" => "sqlite3:#{directory}/race.sqlite3", "RAILS_ENV" => "test", "RAILS_MAX_THREADS" => "5" },
          RbConfig.ruby, Rails.root.join("bin/rails").to_s, "runner", script
        )
        assert status.success?, output
      end
    end
  end
end
