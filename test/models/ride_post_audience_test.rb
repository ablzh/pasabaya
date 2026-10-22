# frozen_string_literal: true

require "test_helper"

class RidePostAudienceTest < ActiveSupport::TestCase
  setup do
    @origin = Location.create!(name: "Test Origin Hub", location_type: :city)
    @destination = Location.create!(name: "Test Dest Hub", location_type: :city)

    @male_driver = users(:one) # male, verified member of Accenture (:one)
    @male_driver.update!(gender: :male)

    @female_driver = users(:two) # female, verified member of UP (:two)
    @female_driver.update!(gender: :female)

    @community = communities(:one)
  end

  test "hub-only ride requires community" do
    ride = RidePost.new(
      user: @male_driver,
      origin: @origin,
      destination: @destination,
      seats: 3,
      remaining_seats: 3,
      status: :active,
      visibility: :hub_only,
      community: nil,
      departure_time: 1.day.from_now
    )
    assert_not ride.valid?
    assert ride.errors.of_kind?(:community, :blank)
  end

  test "hub-only ride requires driver to be verified member of that community" do
    unverified_community = communities(:two) # @male_driver is not member of UP Diliman

    ride = RidePost.new(
      user: @male_driver,
      origin: @origin,
      destination: @destination,
      seats: 3,
      remaining_seats: 3,
      status: :active,
      visibility: :hub_only,
      community: unverified_community,
      departure_time: 1.day.from_now
    )
    assert_not ride.valid?
    assert ride.errors.of_kind?(:community, :unverified_membership)
  end

  test "ladies-only ride requires driver to be female" do
    ride = RidePost.new(
      user: @male_driver, # male driver
      origin: @origin,
      destination: @destination,
      seats: 3,
      remaining_seats: 3,
      status: :active,
      ladies_only: true,
      departure_time: 1.day.from_now
    )
    assert_not ride.valid?
    assert ride.errors.of_kind?(:ladies_only, :ineligible_driver)
  end

  test "visible_to scopes rides correctly across guest, male, and female community members" do
    # 1. Public ride
    public_ride = RidePost.create!(
      user: @male_driver,
      origin: @origin,
      destination: @destination,
      seats: 3,
      remaining_seats: 3,
      status: :active,
      visibility: :public_ride,
      departure_time: 2.days.from_now
    )

    # 2. Ladies-only ride
    ladies_ride = RidePost.create!(
      user: @female_driver,
      origin: @origin,
      destination: @destination,
      seats: 3,
      remaining_seats: 3,
      status: :active,
      visibility: :public_ride,
      ladies_only: true,
      departure_time: 2.days.from_now
    )

    # 3. Hub-only ride (Accenture)
    hub_ride = RidePost.create!(
      user: @male_driver,
      origin: @origin,
      destination: @destination,
      seats: 3,
      remaining_seats: 3,
      status: :active,
      visibility: :hub_only,
      community: @community,
      departure_time: 2.days.from_now
    )

    # Guest user (nil)
    guest_visible = RidePost.visible_to(nil)
    assert_includes guest_visible, public_ride
    assert_not_includes guest_visible, ladies_ride
    assert_not_includes guest_visible, hub_ride

    # Male driver (owns hub_ride & public_ride, member of accenture, not female)
    male_visible = RidePost.visible_to(@male_driver)
    assert_includes male_visible, public_ride
    assert_includes male_visible, hub_ride
    assert_not_includes male_visible, ladies_ride

    # Female user (not member of accenture)
    female_visible = RidePost.visible_to(@female_driver)
    assert_includes female_visible, public_ride
    assert_includes female_visible, ladies_ride
    assert_not_includes female_visible, hub_ride
  end

  test "passenger cannot book ladies-only or hub-only ride if ineligible" do
    ladies_ride = RidePost.create!(
      user: @female_driver,
      origin: @origin,
      destination: @destination,
      seats: 3,
      remaining_seats: 3,
      status: :active,
      visibility: :public_ride,
      ladies_only: true,
      departure_time: 2.days.from_now
    )

    # Male passenger tries to book ladies-only ride
    booking = Booking.new(ride_post: ladies_ride, passenger: @male_driver)
    assert_not booking.valid?
    assert booking.errors.of_kind?(:base, :ineligible_passenger)

    # Non-member passenger tries to book hub-only ride
    hub_ride = RidePost.create!(
      user: @male_driver,
      origin: @origin,
      destination: @destination,
      seats: 3,
      remaining_seats: 3,
      status: :active,
      visibility: :hub_only,
      community: @community, # Accenture
      departure_time: 2.days.from_now
    )
    booking2 = Booking.new(ride_post: hub_ride, passenger: @female_driver) # not member of Accenture
    assert_not booking2.valid?
    assert booking2.errors.of_kind?(:base, :ineligible_passenger)
  end
end
