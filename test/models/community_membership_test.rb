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
end
