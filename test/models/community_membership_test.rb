# frozen_string_literal: true

require "test_helper"

class CommunityMembershipTest < ActiveSupport::TestCase
  setup do
    @community = communities(:one) # domain: accenture.com
    @user = User.create!(
      email_address: "new_comm_user@example.com",
      password: "password",
      first_name: "New",
      last_name: "User",
      facebook_profile_url: "https://facebook.com/newuser"
    )
  end

  test "valid membership with matching domain" do
    membership = CommunityMembership.new(
      user: @user,
      community: @community,
      institutional_email: "new_user@accenture.com"
    )
    assert membership.valid?
  end

  test "rejects institutional email with mismatched domain" do
    membership = CommunityMembership.new(
      user: @user,
      community: @community,
      institutional_email: "new_user@gmail.com"
    )
    assert_not membership.valid?
    assert_includes membership.errors[:institutional_email], "must match the community domain (@accenture.com)"
  end

  test "rejects duplicate membership for same user and community" do
    existing = community_memberships(:one)
    duplicate = CommunityMembership.new(
      user: existing.user,
      community: existing.community,
      institutional_email: "another_juan@accenture.com"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "is already a member of this community"
  end

  test "enforces globally unique institutional email when verified" do
    existing = community_memberships(:one) # juan@accenture.com is verified

    membership = CommunityMembership.new(
      user: @user,
      community: @community,
      institutional_email: existing.institutional_email,
      verified_at: Time.current
    )
    assert_not membership.valid?
    assert_includes membership.errors[:institutional_email], "is already registered and verified by another user"
  end

  test "generates verification token and verifies successfully" do
    membership = CommunityMembership.create!(
      user: @user,
      community: @community,
      institutional_email: "employee@accenture.com"
    )
    assert_not membership.verified?
    assert membership.pending_verification?

    token = membership.generate_token_for(:verification)
    found = CommunityMembership.find_by_token_for(:verification, token)
    assert_equal membership, found

    membership.verify!
    assert membership.reload.verified?
    assert_not membership.pending_verification?
  end

  test "revoke cancels upcoming passenger bookings and driver offers in the hub" do
    # Verify user in community
    membership = CommunityMembership.create!(
      user: @user,
      community: @community,
      institutional_email: "worker@accenture.com",
      verified_at: Time.current
    )

    driver = users(:one) # verified in accenture.com
    origin = Location.create!(name: "Makati Origin", location_type: :city)
    dest = Location.create!(name: "BGC Destination", location_type: :city)

    # 1. User is passenger on a hub ride
    driver_ride = RidePost.create!(
      user: driver,
      origin: origin,
      destination: dest,
      post_type: :offering,
      seats: 3,
      remaining_seats: 3,
      status: :active,
      visibility: :hub_only,
      community: @community,
      departure_time: 2.days.from_now,
      expected_arrival_at: 2.days.from_now + 2.hours
    )
    booking = Booking.create!(ride_post: driver_ride, passenger: @user, status: :pending)

    # 2. User is driver of an upcoming hub ride
    user_ride = RidePost.create!(
      user: @user,
      origin: origin,
      destination: dest,
      post_type: :offering,
      seats: 2,
      remaining_seats: 2,
      status: :active,
      visibility: :hub_only,
      community: @community,
      departure_time: 3.days.from_now,
      expected_arrival_at: 3.days.from_now + 2.hours
    )

    # Revoke membership
    membership.revoke!

    assert booking.reload.canceled?
    assert user_ride.reload.canceled?
  end

  test "verification token cannot be reused after verification" do
    membership = CommunityMembership.create!(
      user: @user,
      community: @community,
      institutional_email: "reuse_test@accenture.com"
    )

    token = membership.generate_token_for(:verification)
    assert_equal membership, CommunityMembership.find_by_token_for(:verification, token)

    membership.verify!
    assert membership.reload.verified?

    # Token must be invalidated upon verification
    assert_nil CommunityMembership.find_by_token_for(:verification, token)
  end

  test "token generated prior to revocation cannot verify a revoked membership" do
    membership = CommunityMembership.create!(
      user: @user,
      community: @community,
      institutional_email: "revoked_token_test@accenture.com"
    )

    token = membership.generate_token_for(:verification)
    membership.revoke!

    # Old token cannot locate membership
    assert_nil CommunityMembership.find_by_token_for(:verification, token)

    assert_raises(ActiveRecord::RecordInvalid) do
      membership.verify!
    end
  end

  test "revoke cancels fulfilled upcoming driver offers in the hub" do
    membership = CommunityMembership.create!(
      user: @user,
      community: @community,
      institutional_email: "full_offer_driver@accenture.com",
      verified_at: Time.current
    )

    origin = Location.create!(name: "Makati Full", location_type: :city)
    dest = Location.create!(name: "BGC Full", location_type: :city)

    fulfilled_ride = RidePost.create!(
      user: @user,
      origin: origin,
      destination: dest,
      post_type: :offering,
      seats: 1,
      remaining_seats: 0,
      status: :fulfilled,
      visibility: :hub_only,
      community: @community,
      departure_time: 3.days.from_now,
      expected_arrival_at: 3.days.from_now + 2.hours
    )

    membership.revoke!
    assert fulfilled_ride.reload.canceled?
  end

  test "revoke cancels passenger booking and restores seats even if driver membership has also expired" do
    driver = @user
    driver_membership = CommunityMembership.create!(
      user: driver,
      community: @community,
      institutional_email: "driver_expired@accenture.com",
      verified_at: 1.month.ago,
      expires_at: 1.year.from_now
    )

    passenger = User.create!(
      email_address: "passenger_comm@example.com",
      password: "password",
      first_name: "Pass",
      last_name: "Comm",
      facebook_profile_url: "https://facebook.com/passcomm"
    )
    passenger_membership = CommunityMembership.create!(
      user: passenger,
      community: @community,
      institutional_email: "passenger_expired@accenture.com",
      verified_at: 1.month.ago,
      expires_at: 1.year.from_now
    )

    origin = locations(:one)
    dest = locations(:two)
    ride = RidePost.create!(
      user: driver,
      origin: origin,
      destination: dest,
      post_type: :offering,
      seats: 3,
      remaining_seats: 2,
      status: :active,
      visibility: :hub_only,
      community: @community,
      departure_time: 3.days.from_now,
      expected_arrival_at: 3.days.from_now + 2.hours
    )
    booking = Booking.create!(ride_post: ride, passenger: passenger, status: :accepted)

    # Both memberships expire before revocation loop
    driver_membership.update_columns(expires_at: 1.day.ago)
    passenger_membership.update_columns(expires_at: 1.day.ago)

    # Passenger membership is revoked first
    assert_nothing_raised do
      passenger_membership.revoke!
    end

    assert booking.reload.canceled?
    assert_equal 3, ride.reload.remaining_seats
  end
end
