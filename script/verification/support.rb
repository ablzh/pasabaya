# frozen_string_literal: true

require_relative "../../config/boot"
require "tmpdir"
require "json"

module Verification
  # Choose disposable storage before Rails boots. Inherited deployment settings
  # must never select a real database for these standalone verification scripts.
  def self.run
    raise "Run with ruby, not rails runner" if defined?(Rails)

    Dir.mktmpdir("pasabaya-verification-") do |directory|
      database = File.join(directory, "primary.sqlite3")
      ENV["RAILS_ENV"] = "test"
      ENV["DATABASE_URL"] = ENV["PRIMARY_DATABASE_URL"] = "sqlite3:#{database}"
      ENV["ACCOUNT_DELETION_REGISTRY_PATH"] = File.join(directory, "accounts.jsonl")
      require_relative "../../config/environment"
      check(ActiveRecord::Base.connection_db_config.database == database, "Verification must use its disposable database")
      ActiveRecord::Base.logger = nil
      ActiveJob::Base.queue_adapter = :test
      ActiveJob::Base.logger = Logger.new(File::NULL)
      ActiveRecord::Schema.verbose = false
      load Rails.root.join("db/schema.rb")
      Users::DeletionRegistry.initialize!
      yield directory
    ensure
      ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord::Base)
    end
  end

  def self.clock
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def self.check(condition, message)
    raise message unless condition
  end

  def self.user(role)
    User.create!(email_address: "#{role}@example.test", password: "synthetic-password", first_name: "Synthetic", last_name: role.capitalize)
  end

  def self.environment
    { ruby: RUBY_VERSION, rails: Rails.version, sqlite: SQLite3::SQLITE_VERSION, platform: RUBY_PLATFORM, rails_env: Rails.env.to_s }
  end
end
