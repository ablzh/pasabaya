require "test_helper"

class DepartureValidationTest < ActiveSupport::TestCase
  test "publishing a past approximate date reports the date error once" do
    route = ride_posts(:one)
    ride = RidePost.new(user: users(:one), origin_id: route.origin_id, destination_id: route.destination_id, seats: 3,
                        departure_date: Date.yesterday, departure_choice: :morning, status: :active)
    assert_not ride.valid?
    assert_equal 1, ride.errors.full_messages.count { |message| message == "Departure date can't be in the past" }
  end

  test "publishing an elapsed exact departure reports the time error once" do
    route = ride_posts(:one)
    ride = RidePost.new(user: users(:one), origin_id: route.origin_id, destination_id: route.destination_id, seats: 3,
                        departure_time: 1.hour.ago, status: :active)
    assert_not ride.valid?
    assert_equal [ "can't be in the past" ], ride.errors[:departure_time]
  end
end
