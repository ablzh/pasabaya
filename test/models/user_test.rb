require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end
  # 1. Accessing fixture data to test custom methods
  test "initials returns capitalized first letters of first and last name" do
    user = users(:one) # "Juan Dela Cruz"
    assert_equal "JD", user.initials
  end

  # 2. Testing validations (negative path)
  test "invalid without facebook_profile_url" do
    user = users(:one)
    user.facebook_profile_url = nil

    assert_not user.valid?
    assert_includes user.errors[:facebook_profile_url], "can't be blank"
  end

  # 3. Testing validations (positive path)
  test "valid with correct facebook_profile_url format" do
    user = users(:one)
    user.facebook_profile_url = "https://facebook.com/custom_username"

    assert user.valid?
  end

  test "changing gender from female withdraws ladies-only driver and passenger commitments" do
    female_user = User.create!(
      email_address: "maria_withdrawal@example.com",
      password: "password",
      first_name: "Maria",
      last_name: "Clara",
      gender: :female,
      facebook_profile_url: "https://facebook.com/mariaclara"
    )

    origin = Location.create!(name: "Origin A", location_type: :city)
    dest = Location.create!(name: "Dest B", location_type: :city)

    # 1. Driver offer
    driver_ride = RidePost.create!(
      user: female_user,
      origin: origin,
      destination: dest,
      post_type: :offering,
      seats: 2,
      remaining_seats: 2,
      status: :active,
      ladies_only: true,
      departure_time: 2.days.from_now,
      expected_arrival_at: 2.days.from_now + 2.hours
    )

    # 2. Passenger booking on another ladies-only ride
    other_driver = User.create!(
      email_address: "other_female@example.com",
      password: "password",
      first_name: "Ana",
      last_name: "Santos",
      gender: :female,
      facebook_profile_url: "https://facebook.com/anasantos"
    )
    other_ride = RidePost.create!(
      user: other_driver,
      origin: origin,
      destination: dest,
      post_type: :offering,
      seats: 2,
      remaining_seats: 2,
      status: :active,
      ladies_only: true,
      departure_time: 3.days.from_now,
      expected_arrival_at: 3.days.from_now + 2.hours
    )
    passenger_booking = Booking.create!(ride_post: other_ride, passenger: female_user, status: :pending)

    # Change gender to male
    female_user.update!(gender: :male)

    assert driver_ride.reload.canceled?
    assert passenger_booking.reload.canceled?
  end

  test "account deletion cancels active passenger bookings and restores driver remaining seats" do
    passenger = User.create!(
      email_address: "passenger_del@example.com",
      password: "password",
      first_name: "Pedro",
      last_name: "Penduko",
      facebook_profile_url: "https://facebook.com/pedro"
    )

    ride = ride_posts(:one)
    initial_remaining = ride.remaining_seats
    booking = Booking.create!(ride_post: ride, passenger: passenger, status: :accepted)
    ride.update!(remaining_seats: initial_remaining - 1)

    passenger.destroy!
    assert_equal initial_remaining, ride.reload.remaining_seats
  end

  test "passenger account deletion preserves driver cancellation notification and allows delivery" do
    driver = users(:one)
    passenger = User.create!(
      email_address: "passenger_del_notif@example.com",
      password: "password",
      first_name: "Pedro",
      last_name: "Penduko",
      facebook_profile_url: "https://facebook.com/pedro"
    )

    ride = ride_posts(:one)
    Booking.create!(ride_post: ride, passenger: passenger, status: :accepted)

    passenger.destroy!

    notif = driver.received_notifications.find_by(event_name: "booking.canceled")
    assert_not_nil notif
    assert_equal ride, notif.notifiable
    assert_nothing_raised do
      NotificationDeliveryJob.perform_now(notif.id)
    end
    assert notif.reload.delivered?
  end

  test "driver account deletion preserves passenger cancellation notification and allows delivery" do
    driver = User.create!(
      email_address: "driver_del_notif@example.com",
      password: "password",
      first_name: "Diego",
      last_name: "Driver",
      facebook_profile_url: "https://facebook.com/diego"
    )
    passenger = users(:two)

    ride = RidePost.create!(
      user: driver,
      origin: locations(:one),
      destination: locations(:two),
      post_type: :offering,
      seats: 3,
      departure_time: 2.days.from_now,
      expected_arrival_at: 2.days.from_now + 2.hours,
      status: :active
    )
    Booking.create!(ride_post: ride, passenger: passenger, status: :accepted)

    driver.destroy!

    notif = passenger.received_notifications.find_by(event_name: "ride.canceled")
    assert_not_nil notif
    assert_nothing_raised do
      NotificationDeliveryJob.perform_now(notif.id)
    end
    assert notif.reload.delivered?
  end

  test "active_trips_count tallies active driver rides and accepted passenger bookings" do
    driver = users(:one)
    passenger = users(:two)

    initial_driver_trips = driver.active_trips_count
    assert initial_driver_trips >= 1

    booking = bookings(:one)
    booking.update_columns(status: Booking.statuses[:accepted])

    assert passenger.active_trips_count >= 1
  end
end
