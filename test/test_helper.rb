ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"
require "tmpdir"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    setup do
      @original_deletion_registry_path = ENV["ACCOUNT_DELETION_REGISTRY_PATH"]
      @deletion_registry_directory = Dir.mktmpdir("pasabaya-deletions-")
      ENV["ACCOUNT_DELETION_REGISTRY_PATH"] = File.join(@deletion_registry_directory, "accounts.jsonl")
      Users::DeletionRegistry.initialize!
      Prosopite.scan
    end

    teardown do
      Prosopite.finish
    ensure
      ENV["ACCOUNT_DELETION_REGISTRY_PATH"] = @original_deletion_registry_path
      FileUtils.remove_entry(@deletion_registry_directory) if @deletion_registry_directory
    end

    def with_stubbed_method(target, name, value)
      original = target.method(name)
      target.define_singleton_method(name) { |*args| value.respond_to?(:call) ? value.call(*args) : value }
      yield
    ensure
      target.define_singleton_method(name, original)
    end

    # Add more helper methods to be used by all tests here...
  end
end
