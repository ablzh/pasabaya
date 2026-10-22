require "test_helper"
require "open3"

class RideSchedulesConcurrencyTest < ActiveSupport::TestCase
  test "concurrent refreshes and a pause racing acceptance preserve unique departures and seats" do
    Dir.mktmpdir("pasabaya-regular-race-") do |directory|
      script = File.join(directory, "race.rb")
      File.write(script, <<~'RUBY')
        require "timeout"
        ActiveRecord::Schema.verbose = false
        load Rails.root.join("db/schema.rb")
        driver = User.create!(email_address: "driver@example.com", password: "password", first_name: "Driver", last_name: "One")
        passenger = User.create!(email_address: "passenger@example.com", password: "password", first_name: "Passenger", last_name: "Two")
        origin, destination = [ "Origin", "Destination" ].map { |name| Location.create!(name: name, location_type: :city) }
        schedule = RideSchedule.create!(user: driver, origin: origin, destination: destination, weekdays_mask: 127, departure_choice: :morning, seats: 3, status: :active)
        RideSchedules::MaterializeService
        RideSchedules::TransitionService
        Bookings::AcceptService
        def concurrently(actions)
          ready = Queue.new
          start = Queue.new
          workers = actions.map do |action|
            Thread.new do
              Rails.application.executor.wrap do
                ActiveRecord::Base.connection_pool.with_connection do
                  ready << true
                  start.pop
                  action.call
                end
              end
            end
          end
          Timeout.timeout(20) do
            actions.size.times { ready.pop }
            actions.size.times { start << true }
            workers.map(&:value)
          end
        end
        concurrently(2.times.map { -> { RideSchedules::MaterializeService.call(RideSchedule.find(schedule.id)) } })
        raise "Duplicate or missing departures" unless schedule.ride_posts.count == 14 && schedule.ride_posts.distinct.count(:schedule_date) == 14
        ride = schedule.ride_posts.find_by!(departure_date: Date.current + 1)
        booking = Bookings::CreateService.call(ride_post: ride, passenger: passenger)
        concurrently([
          -> { RideSchedules::TransitionService.call(schedule: RideSchedule.find(schedule.id), actor: User.find(driver.id), action: :pause) },
          -> {
            begin
              Bookings::AcceptService.call(Booking.find(booking.id), actor: User.find(driver.id))
            rescue Bookings::AcceptService::InvalidStateError
              # Pause may win the transaction before acceptance.
            end
          }
        ])
        raise "Pause did not persist" unless schedule.reload.paused?
        raise "Pending request survived pause" unless booking.reload.accepted? || booking.expired?
        expected_seats = booking.accepted? ? 2 : 3
        raise "Seat inventory disagrees with participation" unless ride.reload.remaining_seats == expected_seats
        raise "Paused departure accepts requests" if ride.bookable?
      RUBY
      output, status = Open3.capture2e(
        { "DATABASE_URL" => "sqlite3:#{directory}/race.sqlite3", "RAILS_ENV" => "test", "RAILS_MAX_THREADS" => "5" },
        RbConfig.ruby, Rails.root.join("bin/rails").to_s, "runner", script
      )
      assert status.success?, output
    end
  end
end
