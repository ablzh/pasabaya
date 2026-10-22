require "test_helper"
require "open3"

class VerificationWorkflowsTest < ActionDispatch::IntegrationTest
  test "a real snapshot restore reconciles deletion and expiry using only disposable storage" do
    Dir.mktmpdir("pasabaya-workflow-guard-") do |directory|
      database = File.join(directory, "existing.sqlite3")
      registry = File.join(directory, "existing.jsonl")
      File.write(database, "Existing database must not be opened")
      File.write(registry, "Existing journal must not be overwritten")
      output, status = Open3.capture2e(
        { "RAILS_ENV" => "production", "DATABASE_URL" => "sqlite3:#{database}", "PRIMARY_DATABASE_URL" => "sqlite3:#{database}", "ACCOUNT_DELETION_REGISTRY_PATH" => registry },
        RbConfig.ruby, Rails.root.join("script/verification/restore_drill.rb").to_s
      )
      assert status.success?, output
      report = JSON.parse(output.lines.last)
      assert_equal "restore_drill", report.fetch("workflow")
      assert_equal "test", report.fetch("environment").fetch("rails_env")
      assert report.fetch("checks").values.all?, report.inspect
      assert_operator report.fetch("restore_and_reconcile_seconds"), :>, 0
      assert_operator report.fetch("simulated_backup_age_seconds"), :>=, 2.days.to_i
      assert_equal "Existing database must not be opened", File.read(database)
      assert_equal "Existing journal must not be overwritten", File.read(registry)
    end
  end
end
