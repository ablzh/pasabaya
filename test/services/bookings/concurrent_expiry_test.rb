require "test_helper"
require "open3"

module Bookings
  class ConcurrentExpiryTest < ActiveSupport::TestCase
    test "concurrent acceptance and duplicate expiry never confirm an elapsed departure" do
      Dir.mktmpdir("pasabaya-booking-race-") do |directory|
        script = File.join(directory, "race.rb")
        File.write(script, <<~RUBY)
          require "active_support/testing/time_helpers"
          require "timeout"
          extend ActiveSupport::Testing::TimeHelpers
          ActiveRecord::Schema.verbose = false
          load Rails.root.join("db/schema.rb")
          driver = User.create!(email_address: "driver@example.com", password: "password", first_name: "Driver", last_name: "One")
          passenger = User.create!(email_address: "passenger@example.com", password: "password", first_name: "Passenger", last_name: "Two")
          origin = Location.create!(name: "Origin", slug: "origin", location_type: :city)
          destination = Location.create!(name: "Destination", slug: "destination", location_type: :city)
          [:exact_time, :morning].each do |choice|
            departure = 1.hour.from_now
            ride = RidePost.create!(user: driver, origin: origin, destination: destination, seats: 3, status: :active,
              departure_date: departure.to_date, departure_choice: choice, departure_time: (departure if choice == :exact_time))
            booking = Booking.create!(ride_post: ride, passenger: passenger)
            travel_to ride.booking_cutoff_at + 1.second do
              ready = Queue.new
              start = Queue.new
              actions = [:accept, :expire, :expire]
              threads = actions.map do |action|
                Thread.new do
                  Rails.application.executor.wrap do
                    ActiveRecord::Base.connection_pool.with_connection do
                      ready << true
                      start.pop
                      target = Booking.find(booking.id)
                      if action == :accept
                        begin
                          Bookings::AcceptService.call(target, actor: User.find(driver.id))
                          :accepted
                        rescue Bookings::AcceptService::InvalidStateError
                          :rejected
                        end
                      else
                        Bookings::ExpireService.call(target)
                        :expired
                      end
                    end
                  end
                end
              end
              Timeout.timeout(15) do
                actions.size.times { ready.pop }
                actions.size.times { start << true }
                results = threads.map(&:value)
                raise "Elapsed ride accepted" unless results == [:rejected, :expired, :expired]
              end
              raise "Request not expired" unless booking.reload.expired?
              raise "Seat inventory changed" unless ride.reload.remaining_seats == 3
              raise "Duplicate expiration notice" unless Notification.where(notifiable: booking, event_name: "booking.expired").count == 1
              raise "Acceptance notice emitted" if Notification.where(notifiable: booking, event_name: "booking.accepted").exists?
            end
          end
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
