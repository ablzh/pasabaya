require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  %w[production staging].each do |environment|
    test "#{environment} seeds only reference data even when demo data is requested" do
      seed_in(environment, demo: "1") do
        assert_no_difference [ "User.count", "RidePost.count", "CommunityMembership.count" ] do
          load_seeds
        end
        assert Location.exists?(name: "Manila")
        assert Community.exists?(domain: "up.edu.ph")
        assert_not User.exists?(email_address: "admin@example.com")
        assert_raises(RuntimeError) { load Rails.root.join("db/seeds/demo.rb") }
      end
    end
  end

  test "reference seeds replay without adding records or demo accounts" do
    seed_in("development") do
      load_seeds
      ids = seed_record_ids
      load_seeds
      assert_equal ids, seed_record_ids
      assert_not User.exists?(email_address: "driver@example.com")
    end
  end

  test "opted-in local demo seeds replay without duplicate accounts rides or memberships" do
    seed_in("test", demo: "1") do
      load_seeds
      ids = seed_record_ids
      load_seeds
      assert_equal ids, seed_record_ids

      driver = User.find_by!(email_address: "driver@example.com")
      assert_equal [ "active", "draft" ], driver.ride_posts.order(:status).pluck(:status).sort
      assert User.find_by!(email_address: "admin@example.com").admin?
      assert driver.authenticate("password")
    end
  end

  private

  def load_seeds
    capture_io { Prosopite.pause { load Rails.root.join("db/seeds.rb") } }
  end

  def seed_record_ids
    [ Location, Community, User, RidePost, CommunityMembership ].map { |model| model.reorder(:id).pluck(:id) }
  end

  def seed_in(environment, demo: nil)
    original_demo = ENV["SEED_DEMO"]
    ENV["SEED_DEMO"] = demo
    with_stubbed_method(Rails, :env, ActiveSupport::StringInquirer.new(environment)) { yield }
  ensure
    ENV["SEED_DEMO"] = original_demo
  end
end
