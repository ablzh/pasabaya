require "test_helper"

class PassengerSeatsTest < ActiveSupport::TestCase
  [ 0, -1, "1.5", "2places" ].each do |value|
    test "offered passenger seats reject #{value.inspect}" do
      ride = ride_posts(:one)
      ride.seats = value
      assert_not ride.valid?, "accepted #{value.inspect}"
      assert ride.errors[:seats].any?
    end
  end

  test "offered passenger seats have no arbitrary cap" do
    ride = ride_posts(:one)
    ride.seats = 12
    assert ride.valid?, ride.errors.full_messages.join(", ")
    assert_equal 12, ride.remaining_seats
  end
end
