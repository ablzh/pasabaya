# frozen_string_literal: true

require "test_helper"

class CommunitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @community = communities(:two)
    @user = users(:one)
  end

  test "guest can access the hubs index and request a hub" do
    get communities_url
    assert_response :success
    assert_select "a[href='https://www.facebook.com/people/Pasabayaapp-Carpooling-for-the-Community/61589209230043/']"
  end

  test "index succeeds for authenticated user" do
    sign_in_as(@user)
    get communities_url
    assert_response :success
  end

  test "show identifies the community hub" do
    get community_url(@community)
    assert_response :success
    assert_select "h1", @community.name
  end

  test "hub discovery excludes restricted drivers and expired driver memberships before the sweep" do
    hub = communities(:one)
    ride = ride_posts(:one)
    viewer = users(:two)
    viewer.community_memberships.create!(community: hub, institutional_email: "viewer@accenture.com",
      verified_at: Time.current, expires_at: 1.year.from_now)
    ride.update!(visibility: :hub_only, community: hub)
    sign_in_as(viewer)

    get community_url(hub)
    assert_response :success
    assert_select "#ride_post_#{ride.id}"

    @user.update!(booking_freeze_until: 1.hour.from_now)
    get community_url(hub)
    assert_select "#ride_post_#{ride.id}", count: 0

    @user.update!(booking_freeze_until: nil)
    community_memberships(:one).update!(expires_at: 1.second.ago)
    get community_url(hub)
    assert_select "#ride_post_#{ride.id}", count: 0
    assert ride.reload.active?, "Listing eligibility must not depend on the membership revocation sweep"
  end
end
