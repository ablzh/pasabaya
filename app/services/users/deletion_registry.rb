# frozen_string_literal: true

module Users
  class DeletionRegistry
    def self.path
      ENV.fetch("ACCOUNT_DELETION_REGISTRY_PATH") do
        raise "ACCOUNT_DELETION_REGISTRY_PATH is required" if Rails.env.production?

        Rails.root.join("storage", "deletion_registry", "accounts.jsonl").to_s
      end
    end

    def self.initialize!
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |file| file.fsync }
    end

    def self.record!(user, deleted_at:)
      initialize! unless File.exist?(path) || Rails.env.production?
      File.open(path, File::WRONLY | File::APPEND) do |file|
        file.flock(File::LOCK_EX)
        file.puts JSON.generate(user_id: user.id, user_created_at: user.created_at.iso8601(6), deleted_at: deleted_at.iso8601(6))
        file.fsync
      end
    end

    def self.each
      initialize! unless File.exist?(path) || Rails.env.production?
      File.open(path) do |file|
        file.flock(File::LOCK_SH)
        file.each_line { |line| yield JSON.parse(line).fetch_values("user_id", "user_created_at", "deleted_at") }
      end
    end
  end
end
