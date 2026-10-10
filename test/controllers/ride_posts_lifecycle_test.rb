require "test_helper"

class RidePostsLifecycleTest < ActionDispatch::IntegrationTest
  test "draft intent cannot reopen a canceled or completed ride" do
    ride = ride_posts(:one)
    sign_in_as(ride.user)

    ride.update_columns(status: RidePost.statuses[:canceled])
    patch ride_post_url(ride), params: { ride_post: { notes: "Canceled plans" }, intent: "draft" }
    assert_response :see_other
    assert ride.reload.canceled?

    ride.update_columns(status: RidePost.statuses[:completed])
    patch ride_post_url(ride), params: { ride_post: { notes: "Completed plans" }, intent: "draft" }
    assert_response :see_other
    assert ride.reload.completed?
  end

  test "empty drafts stay private and failed publish cannot make them bookable" do
    sign_in_as(users(:one))
    post ride_posts_url, params: { ride_post: { notes: "Planning" }, intent: "draft" }
    assert_response :see_other
    ride = users(:one).ride_posts.order(:id).last
    follow_redirect!
    assert_response :success
    assert_select "button[name='intent'][value='publish']", count: 0
    patch ride_post_url(ride), params: { ride_post: { notes: "Still planning" }, intent: "publish" }
    assert_response :unprocessable_content
    assert ride.reload.draft?
    sign_out
    get ride_post_url(ride)
    assert_response :redirect
  end

  test "draft editing never publishes and an explicit publish activates ride" do
    sign_in_as(users(:one))
    attributes = { seats: 3, origin_id: ride_posts(:one).origin_id, destination_id: ride_posts(:one).destination_id, departure_time: 1.day.from_now }
    post ride_posts_url, params: { ride_post: attributes, intent: "draft" }
    assert_response :see_other
    ride = users(:one).ride_posts.order(:id).last
    assert ride.draft?
    patch ride_post_url(ride), params: { ride_post: attributes }
    assert_response :see_other
    assert ride.reload.draft?
    patch ride_post_url(ride), params: { ride_post: attributes, intent: "publish" }
    assert_response :see_other
    assert ride.reload.bookable?
    get edit_ride_post_url(ride)
    assert_select "input#ride_post_expected_arrival_at", count: 0
  end

  test "guest booking entry follows lifecycle and availability" do
    ride = ride_posts(:one)
    cases = [
      [ :draft, nil, 3 ],
      [ :canceled, 1.day.from_now, 0 ],
      [ :completed, 1.day.ago, 0 ],
      [ :active, 1.hour.ago, 0 ],
      [ :fulfilled, 1.day.from_now, 0 ],
      [ :active, 1.day.from_now, 3 ]
    ]
    cases.each do |status, departure, seats|
      ride.update_columns(status: RidePost.statuses[status], departure_time: departure, remaining_seats: seats)
      sign_in_as(ride.user)
      get ride_post_url(ride)
      assert_response :success
      if status == :draft
        assert_select "a[href='#{edit_ride_post_path(ride)}']"
      else
        sign_out
        get ride_post_url(ride)
        assert_response :success
        assert_select "a[href='#{new_session_path(return_to: ride_post_path(ride))}']", count: ride.bookable? ? 1 : 0
      end
    end
  end

  test "both pending and accepted passenger rows link to their own profiles" do
    sign_in_as(users(:one))
    booking = bookings(:one)
    [ :pending, :accepted ].each do |status|
      booking.update_columns(status: Booking.statuses[status])
      get ride_post_url(booking.ride_post)
      assert_select "a[href='#{user_path(booking.passenger)}']", text: "#{booking.passenger.first_name} #{booking.passenger.last_name}", count: 1
    end
  end

  test "settings passwords have unique IDs and associated labels without changing parameter names" do
    sign_in_as(users(:one))
    get settings_profile_url
    ids = css_select("[id]").map { |element| element["id"] }
    assert_equal ids.uniq, ids
    %w[email_change password_change].each do |namespace|
      id = "#{namespace}_user_password_challenge"
      assert_select "input##{id}[name='user[password_challenge]']"
      assert_select "label[for='#{id}']", text: /\S/, count: 1
    end
  end
end
