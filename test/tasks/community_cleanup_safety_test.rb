require "test_helper"
require Rails.root.join("db/migrate/20261003180040_retain_only_up_community")
require Rails.root.join("db/migrate/20261004000900_cleanup_local_hubs_after_booking_schema")

class CommunityCleanupSafetyTest < ActiveSupport::TestCase
  %w[production staging].each do |environment|
    test "migration preserves non-UP hub data in #{environment}" do
      hub = communities(:one)
      ride = ride_posts(:one)
      ride.update_columns(community_id: hub.id, visibility: RidePost.visibilities[:hub_only])
      with_stubbed_method(Rails, :env, ActiveSupport::StringInquirer.new(environment)) do
        RetainOnlyUpCommunity.new.up
        CleanupLocalHubsAfterBookingSchema.new.up
      end
      assert Community.exists?(hub.id)
      assert_equal hub.id, ride.reload.community_id
      assert ride.hub_only?
    end
  end

  test "production seeds preserve existing restricted non-UP rides" do
    hub = communities(:one)
    ride = ride_posts(:one)
    ride.update_columns(community_id: hub.id, visibility: RidePost.visibilities[:hub_only])
    with_stubbed_method(Rails, :env, ActiveSupport::StringInquirer.new("production")) do
      Prosopite.pause { load Rails.root.join("db/seeds.rb") }
    end
    assert Community.exists?(hub.id)
    assert_equal hub.id, ride.reload.community_id
    assert ride.hub_only?
  end

  test "local cleanup aborts without orphaning a protected trip" do
    hub = communities(:one)
    ride = ride_posts(:one)
    ride.update_columns(community_id: hub.id, visibility: RidePost.visibilities[:hub_only])
    bookings(:one).update_columns(status: Booking.statuses[:accepted])
    assert_raises(ActiveRecord::RecordNotDestroyed) { CleanupLocalHubsAfterBookingSchema.new.up }
    assert Community.exists?(hub.id)
    assert_equal hub.id, ride.reload.community_id
    assert ride.hub_only?
  end
end
