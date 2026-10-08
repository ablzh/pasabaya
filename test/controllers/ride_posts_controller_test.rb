require "test_helper"

class RidePostsControllerTest < ActionDispatch::IntegrationTest
  test "card notes preview is at most 110 characters and two lines without changing stored notes" do
    original = "Long historical note " * 30
    @ride_post.update_columns(notes: original)
    get ride_posts_url(origin_id: @ride_post.origin_id)
    assert_select "#ride_post_#{@ride_post.id} p.line-clamp-2", text: original.truncate(110)
    assert_equal original, @ride_post.reload.notes
  end

  test "unchanged historical long notes allow unrelated form updates" do
    original = "Historical details " * 30
    @ride_post.update_columns(notes: original)
    get edit_ride_post_url(@ride_post)
    assert_select "textarea[name='ride_post[notes]'][maxlength]", count: 0
    assert_select "p", text: "Existing longer notes may be kept unchanged; edited notes must be 300 characters or fewer."

    patch ride_post_url(@ride_post), params: { ride_post: { notes: original, seats: 4 } }
    assert_redirected_to ride_post_url(@ride_post)
    assert_equal 4, @ride_post.reload.seats
    assert_equal original, @ride_post.notes
  end

  test "notes form explains the limit and server rejects oversized notes" do
    get new_ride_post_url
    assert_select "textarea[name='ride_post[notes]'][maxlength='300']"
    assert_select "p", text: "Optional. Up to 300 characters."

    assert_no_difference "RidePost.count" do
      post ride_posts_url, params: { intent: "draft", ride_post: { notes: "a" * 301 } }
    end
    assert_response :unprocessable_content
    assert_select "p", text: "is too long (maximum is 300 characters)"
  end

  test "owner sees their trip notes without their own driver introduction" do
    ride = ride_posts(:one)
    sign_in_as(ride.user)
    get ride_post_url(ride)
    assert_select "h2", text: "Your Trip Notes"
    assert_select "h3", text: /#{ride.user.first_name} #{ride.user.last_name}/, count: 0
    sign_in_as(users(:two))
    get ride_post_url(ride)
    assert_select "h2", text: "Driver's Notes"
    assert_select "h3", text: /#{ride.user.first_name} #{ride.user.last_name}/
  end

  test "missing ride redirects old links to board with useful notice" do
    get ride_post_url("999999-no-longer-here")
    assert_redirected_to ride_posts_url
    assert_equal "The trip is no longer available", flash[:alert]
  end

  test "canonical ride redirect retains chat and response format" do
    ride = ride_posts(:one)
    get ride_post_url(ride.id, tab: "chat")
    assert_redirected_to ride_post_url(ride, tab: "chat")
    get ride_post_url(ride.id, format: :json)
    assert_redirected_to ride_post_url(ride, format: :json)
  end

  test "SEO redirects retain audience filters and departure date" do
    origin = locations(:one)
    destination = locations(:two)
    get ride_posts_url(origin_id: origin.id, destination_id: destination.id,
                       community_id: communities(:one).id, ladies_only: true, departure_date: Date.tomorrow.to_s)
    query = Rack::Utils.parse_query(URI.parse(response.location).query)
    assert_equal communities(:one).id.to_s, query["community_id"]
    assert_equal "true", query["ladies_only"]
    assert_equal Date.tomorrow.to_s, query["departure_date"]
  end
  test "new Hub rides retain their restricted audience" do
    sign_in_as(users(:one))
    get new_ride_post_url(community_id: communities(:one).id)
    assert_response :success
    assert_select "select[name='ride_post[visibility]'] option[value='hub_only'][selected]"
    assert_select "select[name='ride_post[community_id]'] option[value='#{communities(:one).id}'][selected]"
  end

  test "unverified members cannot prefill Hub rides" do
    sign_in_as(users(:two))
    get new_ride_post_url(community_id: communities(:one).id)
    assert_response :not_found
  end

  test "repeat request displays the current booking rather than a canceled one" do
    passenger = users(:two)
    ride = ride_posts(:one)
    bookings(:one).update_columns(status: Booking.statuses[:canceled])
    Booking.create!(ride_post: ride, passenger: passenger, status: :pending)
    sign_in_as(passenger)
    get ride_post_url(ride)
    assert_select "p", text: "Seat Requested"
    assert_select "button", text: "Request Seat", count: 0
  end

  test "booking notice escapes driver names and keeps cancellation action" do
    @ride_post.user.update_columns(first_name: "<a href='/fake'>Driver</a>")
    sign_in_as(users(:two))
    get ride_post_url(@ride_post)
    assert_select ".passenger-booking-content p", text: "Waiting for <a href='/fake'>Driver</a> to accept your request."
    assert_select ".passenger-booking-content a[href='/fake']", count: 0
    assert_select ".passenger-booking-content button", text: "Cancel Request"
  end

  test "search omits departed rides even before the audit runs" do
    ride = ride_posts(:one)
    ride.update_columns(departure_time: 1.hour.ago)
    get ride_posts_url(origin_id: "")
    assert_select "#ride_post_#{ride.id}", count: 0
  end
  test "submitted passenger intent cannot create a passenger ride post" do
    post ride_posts_url, params: { intent: "publish", ride_post: {
      post_type: "requesting", origin_id: @ride_post.origin_id, destination_id: @ride_post.destination_id,
      seats: 2, departure_time: 1.day.from_now, expected_arrival_at: 1.day.from_now + 2.hours
    } }
    assert_response :see_other
    assert RidePost.last.offering?
    assert RidePost.last.bookable?
  end

  setup do
    @user = users(:one)
    @ride_post = ride_posts(:one)
    sign_in_as(@user)
  end

  test "should get index with empty state (blank slate) when no search params are provided" do
    # Sign out because index is accessible to the public/unauthenticated users
    sign_out
    get ride_posts_url
    assert_response :success
    assert_select "h3", "Where are you heading?"
  end

  test "should redirect search with both origin and destination to seo route" do
    sign_out
    get ride_posts_url, params: {
      origin_id: @ride_post.origin_id,
      destination_id: @ride_post.destination_id
    }

    # Проверяем, что произошел редирект на красивый SEO-URL
    assert_redirected_to route_rides_url(
                           origin_slug: @ride_post.origin.slug,
                           destination_slug: @ride_post.destination.slug
                         )
  end

  test "should get index with results when only origin is searched (no redirect)" do
    sign_out
    get ride_posts_url, params: {
      origin_id: @ride_post.origin_id
    }

    # Поиск по одному критерию не должен редиректить
    assert_response :success
  end

  test "should get new" do
    get new_ride_post_url
    assert_response :success
  end

  test "should create ride_post" do
    assert_difference("RidePost.count", 1) do
      post ride_posts_url, params: {
        ride_post: {
          post_type: "offering",
          origin_id: locations(:one).id,
          destination_id: locations(:two).id,
          departure_time: 1.day.from_now,
          expected_arrival_at: 1.day.from_now + 2.hours,
          seats: 3,
          notes: "Leaving early morning"
        }
      }
    end

    assert_redirected_to ride_post_url(RidePost.last)
  end

  test "should show ride_post" do
    sign_out
    get ride_post_url(@ride_post)
    assert_response :success
  end

  test "should allow another signed-in user to show ride_post" do
    get ride_post_url(ride_posts(:two))
    assert_response :success
  end

  test "should get edit" do
    get edit_ride_post_url(@ride_post)
    assert_response :success
  end

  test "should update ride_post" do
    patch ride_post_url(@ride_post), params: {
      ride_post: {
        seats: 4,
        notes: "Updated seats count"
      }
    }
    assert_redirected_to ride_post_url(@ride_post)
  end

  test "should destroy ride_post" do
    assert_difference("RidePost.count", -1) do
      delete ride_post_url(@ride_post)
    end

    assert_redirected_to ride_posts_url
  end

  test "draft offers cannot be viewed by anonymous or non-owner users" do
    @ride_post.update_columns(status: RidePost.statuses[:draft])

    sign_out
    get ride_post_url(@ride_post)
    assert_redirected_to ride_posts_url

    get ride_post_url(@ride_post, format: :json)
    assert_response :forbidden

    sign_in_as(users(:two))
    get ride_post_url(@ride_post)
    assert_redirected_to ride_posts_url

    # Owner can view draft
    sign_in_as(@ride_post.user)
    get ride_post_url(@ride_post)
    assert_response :success
  end

  test "cannot destroy ride_post with accepted bookings" do
    booking = bookings(:one)
    booking.update_columns(status: Booking.statuses[:accepted])

    assert_no_difference("RidePost.count") do
      delete ride_post_url(@ride_post)
    end

    assert_redirected_to ride_post_url(@ride_post)
  end

  test "cannot delete a canceled future trip before its chat retention deadline" do
    bookings(:one).update_columns(status: Booking.statuses[:accepted], accepted_at: 1.hour.ago)
    message = @ride_post.chat_messages.create!(user: @ride_post.user, body: "Coordinate after cancellation")
    RidePosts::CancelService.call(@ride_post, actor: @ride_post.user)

    assert_no_difference [ "RidePost.count", "ChatMessage.count", "Booking.count" ] do
      delete ride_post_url(@ride_post)
    end
    assert_redirected_to ride_post_url(@ride_post)
    assert_equal "Coordinate after cancellation", message.reload.body

    travel_to @ride_post.chat_history_unavailable_at do
      assert_difference "RidePost.count", -1 do
        delete ride_post_url(@ride_post)
      end
      assert_redirected_to ride_posts_url
    end
  end

  test "should not get edit for ride_post owned by another user" do
    other_post = ride_posts(:two)
    get edit_ride_post_url(other_post)
    assert_response :not_found
  end

  test "should not update ride_post owned by another user and leave record unchanged" do
    other_post = ride_posts(:two)
    assert_no_changes -> { other_post.reload.attributes } do
      patch ride_post_url(other_post), params: {
        ride_post: {
          seats: 4,
          notes: "Unauthorized modification"
        }
      }
    end
    assert_response :not_found
  end

  test "should not destroy ride_post owned by another user and leave record intact" do
    other_post = ride_posts(:two)
    assert_no_difference("RidePost.count") do
      delete ride_post_url(other_post)
    end
    assert_response :not_found
    assert RidePost.exists?(other_post.id)
  end

  test "should get route page with dynamic SEO tags and H1" do
    sign_out

    origin = @ride_post.origin
    destination = @ride_post.destination
    expected_url = route_rides_url(origin_slug: origin.slug, destination_slug: destination.slug)

    get expected_url

    assert_response :success
    assert_select "title", text: /Carpool from #{origin.name} to #{destination.name}/
    assert_select "h1", text: /Carpool from #{origin.name} to #{destination.name}/
    assert_select "link[rel='canonical'][href='#{expected_url}']"
    assert_select "meta[property='og:url'][content='#{expected_url}']"
  end

  test "should show ride_post with noindex robots tag" do
    sign_out
    expected_url = ride_post_url(@ride_post)
    get expected_url
    assert_response :success

    assert_select "title", text: /Ride from #{@ride_post.origin.name} to #{@ride_post.destination.name}/
    assert_select "meta[name='robots'][content*='noindex']"
    assert_select "link[rel='canonical'][href='#{expected_url}']"
    assert_select "meta[property='og:url'][content='#{expected_url}']"

    assert_select "meta[name='description']" do |elements|
      assert_match /#{@ride_post.user.first_name}/, elements.first["content"]
    end
  end

  test "owner can cancel their trip" do
    assert_not @ride_post.canceled?

    patch cancel_ride_post_url(@ride_post)

    assert_redirected_to ride_post_url(@ride_post)
    assert_equal "Trip was successfully canceled.", flash[:notice]
    assert @ride_post.reload.canceled?
  end

  test "show page displays cancel trip button for owner" do
    get ride_post_url(@ride_post)
    assert_response :success
    assert_select "form[action='#{cancel_ride_post_path(@ride_post)}']" do
      assert_select "button", text: "Cancel Trip"
    end
  end

  test "handles cancel service error gracefully" do
    original_call = RidePosts::CancelService.method(:call)
    RidePosts::CancelService.define_singleton_method(:call) do |*|
      raise RidePosts::CancelService::Error, "Cannot cancel this trip"
    end

    patch cancel_ride_post_url(@ride_post)
    assert_redirected_to ride_post_url(@ride_post)
    assert_equal "Cannot cancel this trip", flash[:alert]
  ensure
    RidePosts::CancelService.define_singleton_method(:call, original_call)
  end

  test "non-owner cannot cancel someone else's trip" do
    other_post = ride_posts(:two)
    patch cancel_ride_post_url(other_post)
    assert_response :not_found
    assert_not other_post.reload.canceled?
  end

  test "authorized participant sees chat tab and messages container on show" do
    get ride_post_url(@ride_post)
    assert_response :success
    assert_select "div[data-controller*='trip-view']"
    assert_select "button[data-tab-name='chat']"
    assert_select "div[data-trip-view-target='chatPane']"
    assert_select "div", text: /Messaging closes:/
    assert_select "div", text: /Scheduled live-database deletion:/
    assert_select "time", text: /Philippine time \(UTC\+8\)/
  end

  test "authorized participant on canceled trip sees cancellation banner and revised deadlines" do
    bookings(:one).update_columns(status: Booking.statuses[:accepted])
    RidePosts::CancelService.call(@ride_post, actor: @ride_post.user)

    get ride_post_url(@ride_post, tab: "chat")

    assert_response :success
    assert_select "button[data-tab-name='chat']"
    assert_select "span", text: /Coordination/
    assert_select "div", text: /Trip canceled/
    assert_select "div", text: /Coordination messaging remains open for 24 hours/
    assert_select "p", text: /Sending messages disabled 24 hours after trip cancellation/
    assert_select ".chat-deadline-policy[open]", count: 0
    assert_select ".chat-deadline-policy [data-chat-scroll-target='coordinationNotice']", count: 0
    assert_select ".chat-deadlines > [role='status'][data-chat-scroll-target='coordinationNotice']", text: /Trip canceled/
  end

  test "expired chat tab direct navigation redirects to details with alert" do
    @ride_post.update_columns(departure_time: 35.days.ago, expected_arrival_at: 34.days.ago)

    get ride_post_url(@ride_post, tab: "chat")

    assert_redirected_to ride_post_url(@ride_post)
    assert_equal "Chat history for this trip is no longer available.", flash[:alert]
    follow_redirect!
    assert_select "button[data-tab-name='chat']", 0
    assert_select "div[data-trip-view-target='chatPane']", 0
  end

  test "expired chat tab json request returns gone" do
    @ride_post.update_columns(departure_time: 35.days.ago, expected_arrival_at: 34.days.ago)

    get ride_post_url(@ride_post, tab: "chat", format: :json)

    assert_response :gone
    assert_equal "Chat history is no longer available", response.parsed_body["error"]
  end

  test "unauthorized viewer does not see chat tab on show" do
    sign_out
    get ride_post_url(@ride_post)
    assert_response :success
    assert_select "button[data-tab-name='chat']", 0
    assert_select "div[data-trip-view-target='chatPane']", 0
  end

  test "index filters by departure_date" do
    target_date = 2.days.from_now.to_date
    @ride_post.update!(departure_time: target_date.in_time_zone("Asia/Manila").change(hour: 8), expected_arrival_at: nil)
    ride_posts(:two).update!(departure_time: (target_date + 4.days).in_time_zone("Asia/Manila"), expected_arrival_at: nil)

    get ride_posts_url(departure_date: target_date.to_s)
    assert_response :success
    assert_select "#ride_post_#{@ride_post.id}"
    assert_select "#ride_post_#{ride_posts(:two).id}", 0
  end

  test "redirects to seo route preserving departure_date parameter" do
    target_date = 2.days.from_now.to_date.to_s
    get ride_posts_url(
      origin_id: @ride_post.origin_id,
      destination_id: @ride_post.destination_id,
      departure_date: target_date
    )
    assert_redirected_to route_rides_url(
      origin_slug: @ride_post.origin.slug,
      destination_slug: @ride_post.destination.slug,
      departure_date: target_date
    )
  end

  test "empty route search shows notify action for signed in user" do
    post session_url, params: { email_address: users(:two).email_address, password: "password" }

    empty_origin = Location.create!(name: "Empty Origin", location_type: :city)
    empty_dest = Location.create!(name: "Empty Dest", location_type: :city)

    get route_rides_url(origin_slug: empty_origin.slug, destination_slug: empty_dest.slug)
    assert_response :success
    assert_select "h3", text: "No rides found for this route yet"
    assert_select "input[type=submit][value='Notify me when a driver posts this route']"
  end

  test "empty route search shows sign-in and sign-up with preserved search context for guest" do
    sign_out
    empty_origin = Location.create!(name: "Empty Origin 2", location_type: :city)
    empty_dest = Location.create!(name: "Empty Dest 2", location_type: :city)

    get route_rides_url(origin_slug: empty_origin.slug, destination_slug: empty_dest.slug)
    assert_response :success
    assert_select "h3", text: "No rides found for this route yet"
    assert_select "a", text: "Sign in to get notified"
    assert_select "a", text: "Create an account"
  end
end
