require "test_helper"
require "open3"

class RidePostTypeMigrationTest < ActiveSupport::TestCase
  test "removing the sole ride type preserves records constraints and rollback" do
    Dir.mktmpdir("pasabaya-ride-type-") do |directory|
      script = File.join(directory, "upgrade.rb")
      File.write(script, <<~'RUBY')
        ActiveRecord::Migration.verbose = false
        migrations = ActiveRecord::MigrationContext.new(Rails.root.join("db/migrate").to_s)
        previous_version = 20261008150100
        removal_version = 20261009120000
        migrations.migrate(previous_version)
        connection = ActiveRecord::Base.connection
        connection.execute("INSERT INTO users (id, email_address, password_digest, first_name, last_name, created_at, updated_at) VALUES (1, 'driver@example.com', 'unused', 'Driver', 'One', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP), (2, 'passenger@example.com', 'unused', 'Passenger', 'Two', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
        connection.execute("INSERT INTO locations (id, name, created_at, updated_at) VALUES (1, 'Origin', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP), (2, 'Destination', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
        connection.execute("INSERT INTO ride_posts (id, user_id, origin_id, destination_id, seats, remaining_seats, departure_date, departure_choice, departure_time, notes, created_at, updated_at) VALUES (1, 1, 1, 2, 3, 2, '2030-10-04', 4, '2030-10-04 02:00:00', 'Preserved trip', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
        connection.execute("INSERT INTO bookings (id, ride_post_id, passenger_id, created_at, updated_at) VALUES (1, 1, 2, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
        original_ride = connection.select_one("SELECT * FROM ride_posts WHERE id = 1").except("post_type")
        original_booking = connection.select_one("SELECT * FROM bookings WHERE id = 1")

        migrations.migrate(removal_version)

        raise "Ride type remains" if connection.columns(:ride_posts).any? { |column| column.name == "post_type" }
        raise "Ride was changed" unless connection.select_one("SELECT * FROM ride_posts WHERE id = 1") == original_ride
        raise "Booking was changed" unless connection.select_one("SELECT * FROM bookings WHERE id = 1") == original_booking
        raise "Invalid foreign keys" unless connection.select_rows("PRAGMA foreign_key_check").empty?
        raise "Database integrity failed" unless connection.select_value("PRAGMA integrity_check") == "ok"
        begin
          connection.execute("UPDATE ride_posts SET remaining_seats = -1 WHERE id = 1")
          raise "Inventory constraint was lost"
        rescue ActiveRecord::StatementInvalid
          # The retained inventory constraint must still reject invalid capacity.
        end

        migrations.migrate(previous_version)

        raise "Rollback did not restore the driver type" unless connection.select_value("SELECT post_type FROM ride_posts WHERE id = 1").zero?
        begin
          connection.execute("UPDATE ride_posts SET post_type = 1 WHERE id = 1")
          raise "Rollback lost the driver type constraint"
        rescue ActiveRecord::StatementInvalid
          # Rollback restores the original single-type database constraint.
        end

        connection.remove_check_constraint(:ride_posts, name: "check_ride_posts_driver_offers_only")
        connection.change_column_null(:ride_posts, :post_type, true)
        [ "1", "NULL" ].each do |unexpected_type|
          connection.execute("UPDATE ride_posts SET post_type = #{unexpected_type} WHERE id = 1")
          begin
            migrations.migrate(removal_version)
            raise "Unexpected ride type was silently dropped"
          rescue StandardError => error
            raise unless error.message.include?("Unexpected ride post types exist")
          end
          preserved_ride = connection.select_one("SELECT * FROM ride_posts WHERE id = 1")
          raise "Rejected migration changed the ride" unless preserved_ride.except("post_type") == original_ride
          expected_type = unexpected_type == "NULL" ? nil : 1
          raise "Rejected migration relabeled the ride" unless preserved_ride.fetch("post_type") == expected_type
        end
      RUBY
      output, status = Open3.capture2e(
        { "DATABASE_URL" => "sqlite3:#{directory}/upgrade.sqlite3", "RAILS_ENV" => "test", "RAILS_MAX_THREADS" => "1" },
        RbConfig.ruby, Rails.root.join("bin/rails").to_s, "runner", script
      )
      assert status.success?, output
    end
  end
end
