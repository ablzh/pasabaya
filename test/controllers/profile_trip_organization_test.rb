require "test_helper"

class ProfileTripOrganizationTest < ActionDispatch::IntegrationTest
  test "draft management publishes explicitly and reports incomplete or elapsed drafts" do
    ride = ride_posts(:one)
    sign_in_as(ride.user)
    ride.update_columns(status: RidePost.statuses[:draft], expected_arrival_at: nil)
    patch publish_ride_post_url(ride)
    assert_redirected_to user_url(ride.user)
    assert ride.reload.bookable?
    assert_nil ride.expected_arrival_at

    ride.update_columns(status: RidePost.statuses[:draft], origin_id: nil, destination_id: nil, departure_time: nil, departure_date: nil)
    patch publish_ride_post_url(ride)
    assert_redirected_to user_url(ride.user)
    assert ride.reload.draft?
    assert_match /Origin.*Destination.*Departure/i, flash[:alert]
    follow_redirect!
    assert_select "#profile-drafts #ride_post_#{ride.id} a", text: "Edit"

    ride.update_columns(origin_id: locations(:one).id, destination_id: locations(:two).id, departure_time: 1.hour.ago, departure_date: Date.current)
    patch publish_ride_post_url(ride)
    assert ride.reload.draft?
    assert_match /past/, flash[:alert]
    delete ride_post_url(ride)
    assert_redirected_to ride_posts_url
    assert_not RidePost.exists?(ride.id)
  end

  test "other members see only visible published upcoming offers including full rides" do
    ride = ride_posts(:one)
    sign_in_as(users(:two))
    ride.update_columns(status: RidePost.statuses[:fulfilled], remaining_seats: 0)
    get user_url(ride.user)
    assert_select "#profile-active-rides #ride_post_#{ride.id}"
    %i[draft completed canceled].each do |state|
      ride.update_columns(status: RidePost.statuses[state])
      get user_url(ride.user, tab: "bookings")
      assert_select "#ride_post_#{ride.id}", count: 0
      assert_select "#profile-drafts, #profile-history, #profile-departed-rides", count: 0
    end
    ride.update_columns(status: RidePost.statuses[:active], ladies_only: true)
    get user_url(ride.user)
    assert_select "#ride_post_#{ride.id}", count: 0 unless users(:two).female?
    sign_in_as(users(:one))
    ride_posts(:two).update_columns(status: RidePost.statuses[:draft])
    patch publish_ride_post_url(ride_posts(:two))
    assert_response :not_found
    assert ride_posts(:two).reload.draft?
  end

  test "departed offers awaiting completion are distinct from Past and canceled history" do
    ride = ride_posts(:one)
    ride.update_columns(departure_time: 1.hour.ago, departure_date: Date.current)
    sign_in_as(ride.user)
    get user_url(ride.user)
    assert_select "#profile-departed-rides #ride_post_#{ride.id}", text: /Departed/
    assert_select "#profile-history #ride_post_#{ride.id}", count: 0
    ride.update_columns(status: RidePost.statuses[:canceled])
    get user_url(ride.user)
    assert_select "#profile-history #ride_post_#{ride.id}", text: /Canceled/
    patch publish_ride_post_url(ride)
    assert ride.reload.canceled?
    assert_match /Only a private draft/, flash[:alert]
  end

  test "owner separates full upcoming offers from drafts and elapsed history" do
    owner = users(:one)
    ride = ride_posts(:one)
    sign_in_as(owner)
    ride.update_columns(status: RidePost.statuses[:fulfilled], remaining_seats: 0)
    get user_url(owner)
    assert_select "#profile-active-rides #ride_post_#{ride.id}"
    assert_select "#profile-history #ride_post_#{ride.id}", count: 0

    ride.update_columns(status: RidePost.statuses[:draft], origin_id: nil, destination_id: nil, departure_time: nil, departure_date: nil)
    get user_url(owner)
    assert_select "#profile-drafts #ride_post_#{ride.id}"
    assert_select "#profile-active-rides #ride_post_#{ride.id}", count: 0
    assert_select "#profile-drafts button", text: "Publish"
    assert_select "#profile-drafts button", text: "Delete"

    ride.update_columns(status: RidePost.statuses[:completed], origin_id: locations(:one).id, destination_id: locations(:two).id, departure_time: 2.days.ago, departure_date: 2.days.ago.to_date)
    get user_url(owner)
    assert_select "#profile-history #ride_post_#{ride.id}", text: /Past/
    assert_select "#profile-history #ride_post_#{ride.id} a", text: "View"
    assert_select "#profile-active-rides #ride_post_#{ride.id}", count: 0
  end
end
