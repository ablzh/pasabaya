# frozen_string_literal: true

require "test_helper"

class TripReviewTest < ActiveSupport::TestCase
  setup do
    @origin = Location.create!(name: "TripReview Origin", location_type: :city)
    @destination = Location.create!(name: "TripReview Dest", location_type: :city)
    @driver = users(:one)
    @passenger = users(:two)
    @outsider = User.create!(
      email_address: "outsider@example.com",
      password: "password",
      first_name: "Out",
      last_name: "Sider",
      facebook_profile_url: "https://facebook.com/outsider"
    )

    @ride_post = RidePost.create!(
      user: @driver,
      origin: @origin,
      destination: @destination,
      post_type: :offering,
      seats: 3,
      remaining_seats: 2,
      status: :active,
      departure_time: 1.day.from_now,
      expected_arrival_at: 1.day.from_now + 2.hours
    )
    @booking = Booking.create!(ride_post: @ride_post, passenger: @passenger, status: :accepted)
    @ride_post.update_columns(departure_time: 2.hours.ago, expected_arrival_at: 1.hour.ago)
  end

  test "cannot review future trips before departure" do
    future_ride = RidePost.create!(
      user: @driver,
      origin: @origin,
      destination: @destination,
      post_type: :offering,
      seats: 3,
      remaining_seats: 2,
      status: :active,
      departure_time: 1.day.from_now,
      expected_arrival_at: 1.day.from_now + 2.hours
    )
    Booking.create!(ride_post: future_ride, passenger: @passenger, status: :accepted)

    review = TripReview.new(
      ride_post: future_ride,
      reporter: @driver,
      reported_user: @passenger,
      outcome: :passenger_no_show
    )
    assert_not review.valid?
    assert_includes review.errors[:base], "Reviews and no-show reports cannot be submitted before trip departure"
  end

  test "valid review between trip participants" do
    review = TripReview.new(
      ride_post: @ride_post,
      reporter: @driver,
      reported_user: @passenger,
      outcome: :completed,
      notes: "Great passenger, arrived on time!"
    )
    assert review.valid?
  end

  test "cannot review oneself" do
    review = TripReview.new(
      ride_post: @ride_post,
      reporter: @driver,
      reported_user: @driver,
      outcome: :completed
    )
    assert_not review.valid?
    assert_includes review.errors[:reported_user], "cannot be yourself"
  end

  test "cannot review non-participants" do
    review = TripReview.new(
      ride_post: @ride_post,
      reporter: @driver,
      reported_user: @outsider,
      outcome: :completed
    )
    assert_not review.valid?
    assert_includes review.errors[:reported_user], "must be a driver or accepted passenger on this trip"

    review2 = TripReview.new(
      ride_post: @ride_post,
      reporter: @outsider,
      reported_user: @driver,
      outcome: :completed
    )
    assert_not review2.valid?
    assert_includes review2.errors[:reporter], "must be a driver or accepted passenger on this trip"
  end

  test "enforces single review per reporter and subject per trip" do
    TripReview.create!(
      ride_post: @ride_post,
      reporter: @driver,
      reported_user: @passenger,
      outcome: :completed
    )

    duplicate = TripReview.new(
      ride_post: @ride_post,
      reporter: @driver,
      reported_user: @passenger,
      outcome: :passenger_no_show
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:ride_post_id], "has already been reviewed by this user for this trip"
  end
  {
    "undated rides" => { departure_time: nil },
    "drafts" => { status: :draft, departure_time: 2.hours.ago }
  }.each do |description, attributes|
    test "#{description} cannot be reviewed even with an accepted participant" do
      @ride_post.update_columns(attributes)
      review = TripReview.new(ride_post: @ride_post, reporter: @driver, reported_user: @passenger)
      assert_not review.valid?
      assert_includes review.errors[:base], "Reviews require a departed ride offer"
    end
  end
end
