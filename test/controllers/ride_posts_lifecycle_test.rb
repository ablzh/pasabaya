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
    post ride_posts_url, params: { ride_post: { post_type: "offering", notes: "Planning" }, intent: "draft" }
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

  test "draft editing never publishes and an explicit publish permits optional arrival" do
    sign_in_as(users(:one))
    attributes = { post_type: "offering", seats: 3, origin_id: ride_posts(:one).origin_id, destination_id: ride_posts(:one).destination_id, departure_time: 1.day.from_now }
    post ride_posts_url, params: { ride_post: attributes, intent: "draft" }
    assert_response :see_other
    ride = users(:one).ride_posts.order(:id).last
    assert ride.draft?
    get ride_post_url(ride)
    assert_select "p", text: /Expected arrival is optional/
    patch ride_post_url(ride), params: { ride_post: attributes }
    assert_response :see_other
    assert ride.reload.draft?
    patch ride_post_url(ride), params: { ride_post: attributes, intent: "publish" }
    assert_response :see_other
    assert ride.reload.bookable?
    assert_nil ride.expected_arrival_at
    get edit_ride_post_url(ride)
    assert_select "label[for='ride_post_expected_arrival_at']", text: "Expected Arrival Time (optional)"
    assert_select "p", text: /Expected arrival is optional/
  end

  test "availability follows lifecycle before capacity and guest login only promises bookable seats" do
    ride = ride_posts(:one)
    cases = [
      [ :draft, nil, 3, "Unpublished — edit to publish" ],
      [ :canceled, 1.day.from_now, 0, "Canceled — bookings closed" ],
      [ :completed, 1.day.ago, 0, "Past — bookings closed" ],
      [ :active, 1.hour.ago, 0, "Departed — bookings closed" ],
      [ :fulfilled, 1.day.from_now, 0, "Fully booked" ],
      [ :active, 1.day.from_now, 3, "Accepting requests" ]
    ]
    cases.each do |status, departure, seats, wording|
      ride.update_columns(status: RidePost.statuses[status], departure_time: departure, remaining_seats: seats)
      sign_in_as(ride.user)
      get ride_post_url(ride)
      assert_select "p", text: wording
      assert_select "p", text: "Past", count: status == :completed ? 1 : 0
      assert_select "a", text: "Review Trip / Report No-Show", count: 0
      if status == :draft
        assert_select "a", text: "Edit Post"
        assert_select "h2", text: "Seat Requests & Confirmed Passengers", count: 0
      else
        sign_out
        get ride_post_url(ride)
        assert_response :success
        assert_select "a", text: "Login to Request Seat", count: status == :active && departure.future? ? 1 : 0
        assert_select "a", text: "Find another ride", count: ride.bookable? ? 0 : 1
      end
    end
    assert_select "a[href='#{new_session_path(return_to: ride_post_path(ride))}']", text: "Login to Request Seat"
  end

  test "both pending and accepted passenger rows link to their own profiles" do
    sign_in_as(users(:one))
    booking = bookings(:one)
    [ :pending, :accepted ].each do |status|
      booking.update_columns(status: Booking.statuses[status])
      get ride_post_url(booking.ride_post)
      assert_select "a[href='#{user_path(booking.passenger)}']", text: "Maria Clara", count: 1
    end
  end

  test "same day overnight and year rollover arrivals retain their complete dates" do
    sign_in_as(users(:one))
    ride = ride_posts(:one)
    departure = Time.zone.local(Time.current.year + 1, 12, 30, 9)
    [ departure + 3.hours, departure + 1.day, departure + 3.days ].each do |arrival|
      ride.update_columns(departure_time: departure, expected_arrival_at: arrival)
      get ride_post_url(ride)
      assert_select "p", text: "Arrival: #{arrival.strftime('%a, %b %d, %Y • %I:%M %p %Z')}"
    end
  end

  test "forms and search expose driver offers without passenger intent tabs or badges" do
    ride = ride_posts(:one)
    sign_in_as(ride.user)
    get new_ride_post_url
    assert_select "select[name='ride_post[post_type]']", count: 0
    assert_select "label[for='ride_post_seats']", text: "Available passenger seats"
    get ride_posts_url(origin_id: ride.origin_id)
    assert_select "input[name='post_type']", count: 0
    assert_select "#ride_post_#{ride.id}", count: 1
    assert_select "#ride_post_#{ride.id} span", text: /offering|requesting/, count: 0
    get ride_post_url(ride)
    assert_select "span", text: /offering|requesting/, count: 0
    assert_select "h2", text: "Seat Requests & Confirmed Passengers"
  end

  test "settings passwords have unique IDs and associated labels without changing parameter names" do
    sign_in_as(users(:one))
    get settings_profile_url
    ids = css_select("[id]").map { |element| element["id"] }
    assert_equal ids.uniq, ids
    %w[email_change password_change].each do |namespace|
      id = "#{namespace}_user_password_challenge"
      assert_select "input##{id}[name='user[password_challenge]']"
      assert_select "label[for='#{id}']", text: /Current password/, count: 1
    end
  end

  test "home and metadata describe approval chat voluntary expenses and profile limitations" do
    get root_url
    assert_select "p", text: /request a seat, and wait for the driver to approve it/
    assert_select "p", text: /private in-app trip chat/
    assert_select "p", text: /expense sharing among themselves/
    assert_select "p", text: /do not verify identity/
    get ride_post_url(ride_posts(:one))
    assert_select "meta[name='description']" do |meta|
      assert_match /driver approval.*private in-app chat/, meta.first["content"]
    end
  end

  test "cost sharing controls and badges are removed from forms, ride pages, and card listings" do
    ride = ride_posts(:one)
    sign_in_as(users(:one))
    get new_ride_post_url
    assert_response :success
    assert_select "input[name='ride_post[is_free_ride]']", count: 0
    assert_select "input[name='ride_post[share_tolls]']", count: 0
    assert_select "input[name='ride_post[split_gas]']", count: 0

    [ true, false ].each do |free_ride|
      ride.update_columns(is_free_ride: free_ride, share_tolls: !free_ride, split_gas: !free_ride)
      get ride_post_url(ride)
      assert_response :success
      assert_select "span", text: /Libreng Sakay/, count: 0
      assert_select "span", text: /Share Tolls/, count: 0
      assert_select "span", text: /Split Gas/, count: 0
      assert_select "div", text: /Users arrange any expense sharing among themselves/

      get ride_posts_url(origin_id: "")
      assert_response :success
      assert_select "#ride_post_#{ride.id}", count: 1
      assert_select "span", text: /Libreng Sakay/, count: 0
      assert_select "span", text: /Tolls/, count: 0
      assert_select "span", text: /Gas/, count: 0
    end
  end
end
