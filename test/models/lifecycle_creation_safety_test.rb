require "test_helper"

class LifecycleCreationSafetyTest < ActiveSupport::TestCase
  setup do
    @ride = ride_posts(:one)
    @passenger = users(:two)
    @origin = locations(:one)
    @destination = locations(:two)
    bookings(:one).destroy!
  end

  test "a loaded ride cannot receive a request after cancellation" do
    stale_ride = RidePost.find(@ride.id)
    RidePosts::CancelService.call(@ride, actor: users(:one))

    booking = Booking.new(ride_post: stale_ride, passenger: @passenger)
    assert_not booking.save
    assert booking.errors.of_kind?(:ride_post, :unavailable_ride)
    assert_not @ride.bookings.pending.exists?
  end

  test "a loaded ride cannot receive a request after requests close" do
    stale_ride = RidePost.find(@ride.id)
    RidePosts::CloseRequestsService.call(@ride, actor: users(:one))

    booking = Booking.new(ride_post: stale_ride, passenger: @passenger)
    assert_not booking.save
    assert booking.errors.of_kind?(:ride_post, :unavailable_ride)
  end

  test "a loaded passenger cannot save pickup notes after account deletion" do
    stale_passenger = User.find(@passenger.id)
    assert Users::AnonymizeService.call(@passenger)

    booking = Booking.new(ride_post: @ride, passenger: stale_passenger, pickup_notes: "My private pickup address")
    assert_not booking.save
    assert booking.errors.of_kind?(:passenger, :ineligible_passenger)
    assert_not Booking.exists?(passenger_id: @passenger.id, pickup_notes: "My private pickup address")
  end

  %i[draft active].each do |status|
    test "a loaded driver cannot create a #{status} ride after account deletion" do
      stale_driver = User.find(@passenger.id)
      assert Users::AnonymizeService.call(@passenger)
      ride = RidePost.new(user: stale_driver, origin: @origin, destination: @destination,
        seats: 2, departure_time: 2.days.from_now, status: status, notes: "My private driving notes")
      assert_not ride.save
      assert ride.errors.of_kind?(:user, :deleted_account)
    end
  end

  test "a loaded ride cannot restore notes after its driver is anonymized" do
    stale_ride = RidePost.find(@ride.id)
    assert Users::AnonymizeService.call(users(:one))

    assert_not stale_ride.update(notes: "My private address")
    assert stale_ride.errors.of_kind?(:user, :deleted_account)
    assert_nil @ride.reload.notes
  end

  test "a loaded chat participant cannot write after account deletion" do
    booking = Booking.create!(ride_post: @ride, passenger: @passenger, status: :accepted)
    stale_driver = User.find(@ride.user_id)
    assert Users::AnonymizeService.call(users(:one))

    message = ChatMessage.new(ride_post: @ride.reload, user: stale_driver, body: "My private contact details")
    assert_not message.save
    assert_empty ChatMessage.where(user_id: stale_driver.id)
    assert booking.reload.canceled?
  end

  test "a loaded participant cannot submit review notes after account deletion" do
    Booking.create!(ride_post: @ride, passenger: @passenger, status: :accepted, decided_at: 2.hours.ago)
    @ride.update_columns(departure_time: 1.hour.ago, departure_date: Date.current)
    stale_passenger = User.find(@passenger.id)
    assert Users::AnonymizeService.call(@passenger)

    review = TripReview.new(ride_post: @ride, reporter: stale_passenger, reported_user: users(:one), notes: "My private trip notes")
    assert_not review.save
    assert review.errors.of_kind?(:reporter, :ineligible_reporter)
  end

  test "a review about a deleted participant preserves its outcome without restoring notes" do
    Booking.create!(ride_post: @ride, passenger: @passenger, status: :accepted, decided_at: 2.hours.ago)
    @ride.update_columns(departure_time: 1.hour.ago, departure_date: Date.current)
    stale_subject = User.find(@passenger.id)
    assert Users::AnonymizeService.call(@passenger)

    review = TripReview.create!(ride_post: @ride, reporter: users(:one), reported_user: stale_subject,
      outcome: :passenger_no_show, notes: "Their private phone number is 0917-123-4567")

    assert review.reload.passenger_no_show?
    assert_equal @passenger.id, review.reported_user_id
    assert_nil review.notes
  end

  test "a loaded user cannot recreate a route alert after account deletion" do
    stale_passenger = User.find(@passenger.id)
    assert Users::AnonymizeService.call(@passenger)

    subscription = RouteSubscription.new(user: stale_passenger, origin: @origin, destination: @destination)
    assert_not subscription.save
    assert subscription.errors.of_kind?(:user, :deleted_account)
    assert_empty @passenger.route_subscriptions
  end

  test "a loaded user cannot recreate institutional email membership after account deletion" do
    stale_passenger = User.find(@passenger.id)
    community = communities(:one)
    assert Users::AnonymizeService.call(@passenger)

    membership = CommunityMembership.new(user: stale_passenger, community: community,
      institutional_email: "private-person@#{community.domain}")
    assert_not membership.save
    assert membership.errors.of_kind?(:user, :deleted_account)
    assert_empty @passenger.community_memberships
  end
end
