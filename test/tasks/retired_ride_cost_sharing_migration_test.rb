require "test_helper"
require "open3"

class RetiredRideCostSharingMigrationTest < ActiveSupport::TestCase
  test "removing retired flags preserves rides bookings and inventory constraints" do
    Dir.mktmpdir("pasabaya-retired-flags-") do |directory|
      script = File.join(directory, "upgrade.rb")
      File.write(script, <<~'RUBY')
        ActiveRecord::Migration.verbose = false
        migrations = ActiveRecord::MigrationContext.new(Rails.root.join("db/migrate").to_s)
        migrations.migrate(20261004180000)
        connection = ActiveRecord::Base.connection
        connection.execute("INSERT INTO users (id, email_address, password_digest, first_name, last_name, created_at, updated_at) VALUES (1, 'upgrade@example.com', 'unused', 'Driver', 'One', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP), (2, 'passenger@example.com', 'unused', 'Passenger', 'Two', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
        connection.execute("INSERT INTO locations (id, name, created_at, updated_at) VALUES (1, 'Origin', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP), (2, 'Destination', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
        connection.execute("INSERT INTO ride_posts (id, user_id, origin_id, destination_id, seats, remaining_seats, departure_date, departure_choice, departure_time, split_gas, notes, created_at, updated_at) VALUES (1, 1, 1, 2, 3, 3, '2030-10-04', 4, '2030-10-04 02:00:00', 1, 'Preserved trip', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
        connection.execute("INSERT INTO bookings (id, ride_post_id, passenger_id, created_at, updated_at) VALUES (1, 1, 2, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")

        migrations.migrate(20261005120000)

        names = connection.columns(:ride_posts).map(&:name)
        raise "Retired flags remain" unless (names & %w[is_free_ride share_tolls split_gas]).empty?
        raise "Ride was changed" unless connection.select_value("SELECT notes FROM ride_posts WHERE id = 1") == "Preserved trip"
        raise "Booking was removed" unless connection.select_value("SELECT COUNT(*) FROM bookings WHERE id = 1") == 1
        begin
          connection.execute("UPDATE ride_posts SET remaining_seats = -1 WHERE id = 1")
          raise "Inventory constraint was lost"
        rescue ActiveRecord::StatementInvalid
          # The retained inventory constraint must still reject invalid capacity.
        end
        migrations.migrate(20261004180000)
        flags = connection.select_one("SELECT is_free_ride, share_tolls, split_gas FROM ride_posts WHERE id = 1")
        raise "Rollback did not restore defaults" unless flags.values.all?(&:zero?)
      RUBY
      output, status = Open3.capture2e(
        { "DATABASE_URL" => "sqlite3:#{directory}/upgrade.sqlite3", "RAILS_ENV" => "test", "RAILS_MAX_THREADS" => "1" },
        RbConfig.ruby, Rails.root.join("bin/rails").to_s, "runner", script
      )
      assert status.success?, output
    end
  end
end
