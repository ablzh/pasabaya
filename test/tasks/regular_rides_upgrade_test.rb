require "test_helper"
require "open3"

class RegularRidesUpgradeTest < ActiveSupport::TestCase
  test "main-era undated offers and terminal history survive the complete upgrade" do
    Dir.mktmpdir("pasabaya-regular-upgrade-") do |directory|
      script = File.join(directory, "upgrade.rb")
      File.write(script, <<~'RUBY')
        ActiveRecord::Migration.verbose = false
        migrations = ActiveRecord::MigrationContext.new(Rails.root.join("db/migrate").to_s)
        migrations.migrate(20260701031146)
        connection = ActiveRecord::Base.connection
        connection.execute("CREATE TABLE _litestream_lock (id INTEGER)")
        connection.execute("INSERT INTO users (id, email_address, password_digest, first_name, last_name, created_at, updated_at) VALUES (1, 'upgrade@example.com', 'unused', 'Driver', 'One', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
        connection.execute("INSERT INTO locations (id, name, created_at, updated_at) VALUES (1, 'Origin', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP), (2, 'Destination', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
        connection.execute("INSERT INTO ride_posts (id, user_id, post_type, origin_id, destination_id, seats, status, notes, created_at, updated_at) VALUES (1, 1, 0, 1, 2, 3, 0, 'Regular legacy offer', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP), (2, 1, 0, 1, 2, 3, 1, 'Fulfilled history', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP), (3, 1, 0, 1, 2, 3, 2, 'Cancelled history', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
        migrations.migrate(20261005121000)
        raise "Undated fulfilled history was lost" unless connection.select_value("SELECT status FROM ride_posts WHERE id = 2") == 3
        raise "Undated cancellation was lost" unless connection.select_value("SELECT status FROM ride_posts WHERE id = 3") == 2
        connection.execute("INSERT INTO ride_posts (id, user_id, post_type, seats, status, notes, created_at, updated_at) VALUES (4, 1, 0, 2, 4, 'Genuine private draft', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
        migrations.migrate
        migrations.migrate
        raise "Existing records were lost" unless connection.select_value("SELECT COUNT(*) FROM ride_posts") == 4
        raise "Legacy offer was published without consent" unless connection.select_value("SELECT status FROM ride_posts WHERE id = 1") == 4
        raise "Private draft was published" unless connection.select_value("SELECT status FROM ride_posts WHERE id = 4") == 4
        raise "A schedule was invented" unless connection.select_value("SELECT COUNT(*) FROM ride_schedules").zero?
        raise "A date was invented" unless connection.select_value("SELECT COUNT(*) FROM ride_posts WHERE departure_date IS NOT NULL").zero?
        raise "Invalid foreign keys" unless connection.select_rows("PRAGMA foreign_key_check").empty?
        raise "Database integrity failed" unless connection.select_value("PRAGMA integrity_check") == "ok"
        exported = StringIO.new
        ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection_pool, exported)
        raise "Replication metadata leaked into the application schema" if exported.string.include?("_litestream_lock")
      RUBY
      output, status = Open3.capture2e(
        { "DATABASE_URL" => "sqlite3:#{directory}/upgrade.sqlite3", "RAILS_ENV" => "test", "RAILS_MAX_THREADS" => "1" },
        RbConfig.ruby, Rails.root.join("bin/rails").to_s, "runner", script
      )
      assert status.success?, output
    end
  end
end
