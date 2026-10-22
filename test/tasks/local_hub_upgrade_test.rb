require "test_helper"
require "open3"

class LocalHubUpgradeTest < ActiveSupport::TestCase
  test "upgrading an existing local hub ride waits for its dependent tables" do
    Dir.mktmpdir("pasabaya-upgrade-") do |directory|
      script = File.join(directory, "upgrade.rb")
      File.write(script, <<~RUBY)
        ActiveRecord::Migration.verbose = false
        migrations = ActiveRecord::MigrationContext.new(Rails.root.join("db/migrate").to_s)
        migrations.migrate(20261003170002)
        connection = ActiveRecord::Base.connection
        connection.execute("INSERT INTO users (id, email_address, password_digest, first_name, last_name, created_at, updated_at) VALUES (1, 'upgrade@example.com', 'unused', 'Local', 'Driver', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
        connection.execute("INSERT INTO locations (id, name, created_at, updated_at) VALUES (1, 'Origin', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP), (2, 'Destination', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
        connection.execute("INSERT INTO communities (id, name, domain, slug, created_at, updated_at) VALUES (1, 'Disposable', 'local.example', 'disposable', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
        connection.execute("INSERT INTO ride_posts (id, user_id, origin_id, destination_id, community_id, visibility, post_type, seats, remaining_seats, departure_time, created_at, updated_at) VALUES (1, 1, 1, 2, 1, 1, 0, 3, 3, '2030-10-04 02:00:00', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
        migrations.migrate
        raise "Local hub remains" unless connection.select_value("SELECT COUNT(*) FROM communities WHERE domain = 'local.example'").zero?
        raise "Disposable ride remains" unless connection.select_value("SELECT COUNT(*) FROM ride_posts WHERE id = 1").zero?
        raise "Driver was deleted" unless connection.select_value("SELECT COUNT(*) FROM users WHERE id = 1") == 1
      RUBY
      output, status = Open3.capture2e(
        { "DATABASE_URL" => "sqlite3:#{directory}/upgrade.sqlite3", "RAILS_ENV" => "test", "RAILS_MAX_THREADS" => "1" },
        RbConfig.ruby, Rails.root.join("bin/rails").to_s, "runner", script
      )
      assert status.success?, output
    end
  end
end
