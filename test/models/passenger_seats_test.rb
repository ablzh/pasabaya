require "test_helper"

class PassengerSeatsTest < ActiveSupport::TestCase
  test "offered passenger seats are positive integers without arbitrary cap" do
    ride = ride_posts(:one)
    [ 0, -1, "1.5", "2places" ].each do |value|
      ride.seats = value
      assert_not ride.valid?, "accepted #{value.inspect}"
      assert ride.errors[:seats].any?
    end
    ride.seats = 12
    assert ride.valid?, ride.errors.full_messages.join(", ")
    assert_equal 12, ride.remaining_seats
  end
end
