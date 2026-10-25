require "test_helper"

class RidePostsControllerTest < ActionDispatch::IntegrationTest
  test "unchanged historical long notes allow unrelated form updates" do
    original = "Historical details " * 30
    @ride_post.update_columns(notes: original)
    get edit_ride_post_url(@ride_post)
    assert_select "textarea[name='ride_post[notes]'][maxlength]", count: 0

    patch ride_post_url(@ride_post), params: { ride_post: { notes: original, seats: 4 } }
    assert_redirected_to ride_post_url(@ride_post)
    assert_equal 4, @ride_post.reload.seats
    assert_equal original, @ride_post.notes
  end

  test "notes form accepts and preserves the full description" do
    get new_ride_post_url
    assert_select "textarea[name='ride_post[notes]'][maxlength]", count: 0

    notes = "Detailed pickup and luggage information. " * 30
    assert_difference "RidePost.count", 1 do
      post ride_posts_url, params: { intent: "draft", ride_post: { notes: notes } }
    end
    assert_redirected_to ride_post_url(RidePost.last)
    assert_equal notes, RidePost.last.notes
  end

  test "missing ride redirects old links to board with useful notice" do
    get ride_post_url("999999-no-longer-here")
    assert_redirected_to ride_posts_url
    assert_predicate flash[:alert], :present?
  end

  test "canonical ride redirect retains chat tab" do
    ride = ride_posts(:one)
    get ride_post_url(ride.id, tab: "chat")
    assert_redirected_to ride_post_url(ride, tab: "chat")
  end

  test "regular ride departure displays schedule banner with link to schedule" do
    schedule = users(:one).ride_schedules.create!(
      origin: locations(:one),
      destination: locations(:two),
      weekdays_mask: 3,
      departure_choice: :flexible,
      seats: 3,
      status: :active
    )
    ride = ride_posts(:one)
    RidePost.where(id: ride.id).update_all(ride_schedule_id: schedule.id, schedule_date: ride.departure_date)

    get ride_post_url(ride)

    assert_response :success
    assert_select "a[href=?]", ride_schedule_path(schedule)
    assert_includes response.body, "Part of regular schedule"
  end

  test "creation age follows the original offer or schedule instead of generated departures" do
    travel_to Time.current.change(sec: 0) do
      origin = locations(:one)
      destination = locations(:two)
      date = Date.tomorrow
      source, schedules, rides = Prosopite.pause do
        source = @user.ride_posts.create!(status: :draft, created_at: 4.months.ago)
        schedules = [ source, nil ].map do |original|
          @user.ride_schedules.create!(
            source_ride_post: original, origin: origin, destination: destination,
            weekdays_mask: 1 << date.wday, departure_choice: :flexible, seats: 3,
            status: :active, created_at: 2.weeks.ago
          )
        end
        rides = schedules.map do |schedule|
          schedule.ride_posts.create!(schedule.ride_attributes(date).merge(schedule_date: date))
        end
        rides << @user.ride_posts.create!(origin: origin, destination: destination,
          departure_date: date, departure_choice: :flexible, seats: 3, created_at: 1.week.ago)
        [ source, schedules, rides ]
      end
      creation_dates = [ source.created_at, schedules.last.created_at, rides.last.created_at ]

      get route_rides_url(origin_slug: origin.slug, destination_slug: destination.slug)
      assert_response :success
      rides.zip(creation_dates).each do |ride, created_at|
        age = Regexp.escape(ApplicationController.helpers.time_ago_in_words(created_at))
        assert_select "#ride_post_#{ride.id}", text: /Created\s+#{age}\s+ago/
      end

      rides.zip(creation_dates).each do |ride, created_at|
        get ride_post_url(ride)
        assert_response :success
        age = Regexp.escape(ApplicationController.helpers.time_ago_in_words(created_at))
        assert_select ".ride-detail-header", text: /Created\s+#{age}\s+ago/
      end

      schedules.zip(creation_dates).each do |schedule, created_at|
        get ride_schedule_url(schedule)
        assert_response :success
        age = Regexp.escape(ApplicationController.helpers.time_ago_in_words(created_at))
        assert_select "time[datetime=?]", created_at.iso8601, text: /Created\s+#{age}\s+ago/
      end
    end
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
    current_booking = Booking.create!(ride_post: ride, passenger: passenger, status: :pending)
    sign_in_as(passenger)
    get ride_post_url(ride)
    assert_select "form[action='#{cancel_booking_path(current_booking)}']"
    assert_select "form[action='#{ride_post_bookings_path(ride)}']", count: 0
  end

  test "booking notice escapes driver names and keeps cancellation action" do
    @ride_post.user.update_columns(first_name: "<a href='/fake'>Driver</a>")
    sign_in_as(users(:two))
    get ride_post_url(@ride_post)
    assert_select ".passenger-booking-content p", text: /#{Regexp.escape(@ride_post.user.first_name)}/
    assert_select ".passenger-booking-content a[href='/fake']", count: 0
    assert_select ".passenger-booking-content form[action='#{cancel_booking_path(bookings(:one))}'] button"
  end

  test "search omits departed rides even before the audit runs" do
    ride = ride_posts(:one)
    ride.update_columns(departure_time: 1.hour.ago)
    get ride_posts_url(origin_id: "")
    assert_select "#ride_post_#{ride.id}", count: 0
  end

  test "search and popular routes exclude restricted drivers and recover after a freeze expires" do
    travel_to Time.current.change(usec: 0) do
      sign_out
      origin = @ride_post.origin
      destination = @ride_post.destination
      route_path = route_rides_path(origin_slug: origin.slug, destination_slug: destination.slug)

      get ride_posts_url(origin_id: origin.id)
      assert_select "#ride_post_#{@ride_post.id}"
      get root_url
      assert_select "a[href='#{route_path}']"

      @user.update!(banned_at: Time.current)
      get ride_posts_url(origin_id: origin.id)
      assert_select "#ride_post_#{@ride_post.id}", count: 0
      get root_url
      assert_select "a[href='#{route_path}']", count: 0

      @user.update!(banned_at: nil, booking_freeze_until: 10.minutes.from_now)
      get ride_posts_url(origin_id: origin.id)
      assert_select "#ride_post_#{@ride_post.id}", count: 0

      travel 11.minutes
      get ride_posts_url(origin_id: origin.id)
      assert_select "#ride_post_#{@ride_post.id}"
      get root_url
      assert_select "a[href='#{route_path}']"
    end
  end

  test "restricted drivers cannot accept pending requests but can still decline them" do
    booking = bookings(:one)
    @user.update!(booking_freeze_until: 1.hour.from_now)

    get ride_post_url(@ride_post)

    assert_response :success
    assert_select "form[action='#{accept_booking_path(booking)}'] button[disabled]"
    assert_select "form[action='#{decline_booking_path(booking)}'] button:not([disabled])"
    assert booking.reload.pending?
  end

  setup do
    @user = users(:one)
    @ride_post = ride_posts(:one)
    sign_in_as(@user)
  end

  test "ride pages reject JSON paths and Accept headers" do
    sign_out
    [ ride_posts_url(format: :json), ride_post_url(@ride_post, format: :json),
      new_ride_post_url(format: :json), edit_ride_post_url(@ride_post, format: :json) ].each do |url|
      get url
      assert_response :not_acceptable
    end

    get ride_posts_url, headers: { "Accept" => "application/json" }
    assert_response :not_acceptable
  end

  test "JSON ride mutations are rejected before changing records" do
    original_attributes = @ride_post.attributes
    original_booking = bookings(:one).attributes
    assert_no_difference [ "RidePost.count", "RideSchedule.count", "Booking.count", "Notification.count" ] do
      post ride_posts_url(format: :json), params: { ride_post: { notes: "JSON draft" }, intent: "draft" }
      assert_response :not_acceptable

      post ride_posts_url(format: :json), params: { ride_type: "regular", ride_post: { notes: "JSON schedule" } }
      assert_response :not_acceptable

      patch ride_post_url(@ride_post, format: :json), params: { ride_post: { notes: "JSON update" } }
      assert_response :not_acceptable

      delete ride_post_url(@ride_post, format: :json)
      assert_response :not_acceptable

      [ cancel_ride_post_url(@ride_post, format: :json), publish_ride_post_url(@ride_post, format: :json),
        close_requests_ride_post_url(@ride_post, format: :json) ].each do |url|
        patch url
        assert_response :not_acceptable
      end
    end
    assert_equal original_attributes, @ride_post.reload.attributes
    assert_equal original_booking, bookings(:one).reload.attributes
  end

  test "Turbo form requests still negotiate HTML for redirects and validation errors" do
    headers = { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }
    assert_difference "RidePost.count", 1 do
      post ride_posts_url, params: { ride_post: { notes: "Turbo draft" }, intent: "draft" }, headers: headers
    end
    assert_response :see_other
    assert_redirected_to ride_post_url(RidePost.last)

    assert_no_difference "RidePost.count" do
      post ride_posts_url, params: { ride_post: { seats: 0, notes: "Turbo draft" }, intent: "draft" }, headers: headers
    end
    assert_response :unprocessable_content
    assert_equal "text/html", response.media_type
    assert_select "#ride_post_seats[aria-invalid='true'][value='0']"
    assert_select "textarea[name='ride_post[notes]']", text: "Turbo draft"
  end

  test "should get index with empty state (blank slate) when no search params are provided" do
    # Sign out because index is accessible to the public/unauthenticated users
    sign_out
    get ride_posts_url
    assert_response :success
    assert_select "form[action='#{ride_posts_path}']"
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
          origin_id: locations(:one).id,
          destination_id: locations(:two).id,
          departure_time: 1.day.from_now,
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
    assert_select "title", text: /#{Regexp.escape(origin.name)}.*#{Regexp.escape(destination.name)}/
    assert_select "h1", text: /#{Regexp.escape(origin.name)}.*#{Regexp.escape(destination.name)}/
    assert_select "link[rel='canonical'][href='#{expected_url}']"
    assert_select "meta[property='og:url'][content='#{expected_url}']"
  end

  test "should show ride_post with noindex robots tag" do
    sign_out
    expected_url = ride_post_url(@ride_post)
    get expected_url
    assert_response :success

    assert_select "title", text: /#{Regexp.escape(@ride_post.origin.name)}.*#{Regexp.escape(@ride_post.destination.name)}/
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
    assert_predicate flash[:notice], :present?
    assert @ride_post.reload.canceled?
  end

  test "show page displays cancel trip button for owner" do
    get ride_post_url(@ride_post)
    assert_response :success
    assert_select "form[action='#{cancel_ride_post_path(@ride_post)}']" do
      assert_select "button[type='submit']"
    end
  end

  test "handles cancel service error gracefully" do
    original_call = RidePosts::CancelService.method(:call)
    RidePosts::CancelService.define_singleton_method(:call) do |*|
      raise RidePosts::CancelService::Error, "Cannot cancel this trip"
    end

    patch cancel_ride_post_url(@ride_post)
    assert_redirected_to ride_post_url(@ride_post)
    assert_predicate flash[:alert], :present?
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
    assert_select "time[datetime='#{@ride_post.chat_messaging_closes_at.iso8601}']"
    assert_select "time[datetime='#{@ride_post.chat_history_unavailable_at.iso8601}']"
  end

  test "authorized participant on canceled trip sees cancellation banner and revised deadlines" do
    bookings(:one).update_columns(status: Booking.statuses[:accepted])
    RidePosts::CancelService.call(@ride_post, actor: @ride_post.user)
    @ride_post.reload

    get ride_post_url(@ride_post, tab: "chat")

    assert_response :success
    assert_select "button[data-tab-name='chat']"
    assert_select "[role='status'][data-chat-scroll-target='coordinationNotice']", text: /\S/
    assert_select "time[datetime='#{@ride_post.chat_messaging_closes_at.iso8601}']"
    assert_select "time[datetime='#{@ride_post.chat_history_unavailable_at.iso8601}']"
    assert_select "form[action='#{ride_post_chat_messages_path(@ride_post)}']"
  end

  test "expired chat tab direct navigation redirects to details with alert" do
    @ride_post.update_columns(departure_time: 35.days.ago)

    get ride_post_url(@ride_post, tab: "chat")

    assert_redirected_to ride_post_url(@ride_post)
    assert_predicate flash[:alert], :present?
    follow_redirect!
    assert_select "button[data-tab-name='chat']", 0
    assert_select "div[data-trip-view-target='chatPane']", 0
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
    @ride_post.update!(departure_time: target_date.in_time_zone("Asia/Manila").change(hour: 8))
    ride_posts(:two).update!(departure_time: (target_date + 4.days).in_time_zone("Asia/Manila"))

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
    assert_select "form[action='#{route_subscriptions_path}'] input[type='submit']"
    assert_select "input[name='route_subscription[origin_id]'][value='#{empty_origin.id}']"
    assert_select "input[name='route_subscription[destination_id]'][value='#{empty_dest.id}']"
  end

  test "empty route search shows sign-in and sign-up with preserved search context for guest" do
    sign_out
    empty_origin = Location.create!(name: "Empty Origin 2", location_type: :city)
    empty_dest = Location.create!(name: "Empty Dest 2", location_type: :city)

    get route_rides_url(origin_slug: empty_origin.slug, destination_slug: empty_dest.slug)
    assert_response :success
    return_to = route_rides_path(origin_slug: empty_origin.slug, destination_slug: empty_dest.slug)
    assert_select "a[href='#{new_session_path(return_to: return_to)}']"
    assert_select "a[href='#{sign_up_path(return_to: return_to)}']"
  end

  test "single location search shows partial route alert form for signed in user" do
    sign_in_as(users(:two))
    empty_origin = Location.create!(name: "Solo Origin", location_type: :city)

    get ride_posts_url(origin_id: empty_origin.id)
    assert_response :success
    assert_select "form#route_subscription_partial_form"
    assert_select "input[name='route_subscription[origin_id]'][value='#{empty_origin.id}']"
    assert_select "select[name='route_subscription[destination_id]']"
  end

  test "freeform route query resolves locations and redirects or shows route alert" do
    empty_origin = Location.create!(name: "Pasig", location_type: :city)
    empty_dest = Location.create!(name: "Tagaytay", location_type: :city)

    get ride_posts_url(q: "Pasig to Tagaytay")
    assert_redirected_to route_rides_url(origin_slug: empty_origin.slug, destination_slug: empty_dest.slug)
  end

  test "unrecognized location searches show route suggestions instead of unrelated rides" do
    %i[q query origin destination].each do |parameter|
      get ride_posts_url(parameter => "zzzz_nonexistent_city")

      assert_response :success
      assert_select "#ride_posts [id^='ride_post_']", count: 0
      assert_select "a[href='#{route_rides_path(origin_slug: locations(:one).slug, destination_slug: locations(:two).slug)}']"
    end
  end

  test "a route with an unrecognized endpoint does not broaden the search" do
    [ { q: "Manila to zzzz_nonexistent_city" }, { origin: "Manila", destination: "zzzz_nonexistent_city" } ].each do |search|
      get ride_posts_url(search)

      assert_response :success
      assert_select "#ride_posts [id^='ride_post_']", count: 0
      assert_select "form#route_subscription_partial_form"
    end
  end

  test "unrecognized queries are not dropped by a route redirect" do
    get ride_posts_url(q: "zzzz_nonexistent_city", origin_id: @ride_post.origin_id, destination_id: @ride_post.destination_id)

    assert_response :success
    assert_select "#ride_posts [id^='ride_post_']", count: 0
  end
end
