require "test_helper"

class RidePostTest < ActiveSupport::TestCase
  test "invalid if departure time is in the past" do
    # You can fetch a post from your ride_posts.yml fixture
    ride_post = ride_posts(:one)

    # Set the departure time to 1 hour ago
    ride_post.departure_time = 1.hour.ago

    assert_not ride_post.valid?
    assert_includes ride_post.errors[:departure_time], "can't be in the past"
  end
end
