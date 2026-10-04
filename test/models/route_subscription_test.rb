# frozen_string_literal: true

require "test_helper"

class RouteSubscriptionTest < ActiveSupport::TestCase
  setup do
    @user = users(:two)
    @driver = users(:one)
    @origin = locations(:one)
    @destination = locations(:two)
  end

  test "validates required attributes and distinct locations" do
    sub = RouteSubscription.new
    assert_not sub.valid?
    assert sub.errors[:user_id].present?
    assert sub.errors[:origin_id].present?
    assert sub.errors[:destination_id].present?

    sub = RouteSubscription.new(user: @user, origin: @origin, destination: @origin)
    assert_not sub.valid?
    assert_includes sub.errors[:destination], "must differ from origin"
  end

  test "cannot subscribe to a past departure date" do
    sub = RouteSubscription.new(
      user: @user,
      origin: @origin,
      destination: @destination,
      departure_date: 1.day.ago.to_date
    )
    assert_not sub.valid?
    assert_includes sub.errors[:departure_date], "can't be in the past"
  end

  test "prevents duplicate active subscriptions for same user and search filters" do
    sub1 = RouteSubscription.create!(
      user: @user,
      origin: @origin,
      destination: @destination,
      departure_date: 2.days.from_now.to_date
    )

    sub2 = RouteSubscription.new(
      user: @user,
      origin: @origin,
      destination: @destination,
      departure_date: 2.days.from_now.to_date
    )
    assert_not sub2.valid?
    assert_includes sub2.errors[:user_id], "already has an active route alert for this search"

    # Canceling the first allows creating a new one
    sub1.cancel!
    assert sub2.valid?
  end

  test "matches upcoming ride when no date is specified" do
    sub = RouteSubscription.create!(
      user: @user,
      origin: @origin,
      destination: @destination
    )

    ride = RidePost.create!(
      user: @driver,
      origin: @origin,
      destination: @destination,
      seats: 3,
      departure_date: 2.days.from_now.to_date,
      departure_choice: :morning,
      status: :active
    )

    assert sub.matches?(ride)
  end

  test "matches exact date when departure date is specified" do
    target_date = 3.days.from_now.to_date
    sub = RouteSubscription.create!(
      user: @user,
      origin: @origin,
      destination: @destination,
      departure_date: target_date
    )

    same_date_ride = RidePost.create!(
      user: @driver,
      origin: @origin,
      destination: @destination,
      seats: 3,
      departure_date: target_date,
      departure_choice: :morning,
      status: :active
    )

    different_date_ride = RidePost.create!(
      user: @driver,
      origin: @origin,
      destination: @destination,
      seats: 3,
      departure_date: 4.days.from_now.to_date,
      departure_choice: :morning,
      status: :active
    )

    assert sub.matches?(same_date_ride)
    assert_not sub.matches?(different_date_ride)
  end

  test "excludes driver's own offers" do
    sub = RouteSubscription.create!(
      user: @driver,
      origin: @origin,
      destination: @destination
    )

    ride = RidePost.create!(
      user: @driver,
      origin: @origin,
      destination: @destination,
      seats: 3,
      departure_date: 2.days.from_now.to_date,
      departure_choice: :morning,
      status: :active
    )

    assert_not sub.matches?(ride)
  end

  test "enforces ladies only boundary and access rechecking" do
    male_user = users(:one)
    female_user = users(:two)

    sub_male = RouteSubscription.create!(
      user: male_user,
      origin: @origin,
      destination: @destination
    )

    sub_female = RouteSubscription.create!(
      user: female_user,
      origin: @origin,
      destination: @destination
    )

    female_driver = User.create!(
      email_address: "female_driver@example.com",
      password: "password",
      first_name: "Female",
      last_name: "Driver",
      gender: :female
    )
    ladies_ride = RidePost.create!(
      user: female_driver,
      origin: @origin,
      destination: @destination,
      seats: 3,
      departure_date: 2.days.from_now.to_date,
      departure_choice: :morning,
      ladies_only: true,
      status: :active
    )

    # Female subscriber matches ladies-only ride; male subscriber does not
    assert sub_female.matches?(ladies_ride)
    assert_not sub_male.matches?(ladies_ride)
  end
end
