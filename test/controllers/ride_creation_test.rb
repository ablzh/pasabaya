require "test_helper"

class RideCreationTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.zone.local(2026, 10, 8, 10)
    @driver = users(:one)
    @origin = locations(:one)
    @destination = locations(:two)
    @attributes = {
      origin_id: @origin.id, destination_id: @destination.id,
      departure_choice: "exact_time", exact_departure_time: "08:00", seats: 3,
      notes: "Meet near the station", weekday_ids: [ "1", "3", "5" ]
    }
    sign_in_as @driver
  end

  teardown { travel_back }

  test "both ride types use one creation screen and submit endpoint" do
    get new_ride_post_url
    assert_response :success
    assert_select "form[action='#{ride_posts_path}']", count: 1
    assert_select "input[name='ride_type'][value='one_time'][checked]"
    assert_select "input[name='ride_type'][value='regular']"
    assert_select "a[href='/regular-rides/new']", count: 0
    assert_select "fieldset[data-ride-creation-target='regularFields'][disabled]"

    get new_ride_post_url(ride_type: "regular", community_id: communities(:one).id)
    assert_response :success
    assert_select "h1", text: "Post a Ride"
    assert_select "form[action='#{ride_posts_path}']", count: 1
    assert_select "input[name='ride_type'][value='regular'][checked]"
    assert_select "fieldset[data-ride-creation-target='oneTimeFields'][disabled]"
    assert_select "select[name='ride_post[visibility]'] option[value='hub_only'][selected]"
    assert_select "select[name='ride_post[community_id]'] option[value='#{communities(:one).id}'][selected]"
  end

  test "separate regular creation endpoints are not exposed" do
    get "/regular-rides/new"
    assert_response :not_found
    assert_nil response.headers["Location"]

    assert_no_difference [ "RideSchedule.count", "RidePost.count" ] do
      post "/regular-rides", params: { ride_schedule: @attributes, intent: "publish" }
    end
    assert_response :not_found
  end

  test "regular submission creates a schedule with independent dated departures" do
    assert_difference "RideSchedule.count", 1 do
      post ride_posts_url, params: { ride_type: "regular", intent: "publish", ride_post: @attributes }
    end
    schedule = @driver.ride_schedules.last
    assert_redirected_to schedule
    assert schedule.active?
    assert_equal "08:00", schedule.departure_clock
    assert_equal [ 1, 3, 5 ], schedule.weekday_ids
    assert_equal 6, schedule.ride_posts.count
    assert schedule.ride_posts.all? { |ride| ride.seats == 3 && ride.remaining_seats == 3 }
  end

  test "invalid regular publication retains inputs and exposes focusable corrections" do
    assert_no_difference [ "RideSchedule.count", "RidePost.count" ] do
      post ride_posts_url, params: { ride_type: "regular", intent: "publish",
        ride_post: @attributes.merge(weekday_ids: [], exact_departure_time: "") }
    end
    assert_response :unprocessable_content
    assert_select "input[name='ride_type'][value='regular'][checked]"
    assert_select "textarea#ride_post_notes", text: @attributes[:notes]
    assert_select "#ride_post_origin_id option[value='#{@attributes[:origin_id]}'][selected]"
    assert_select "#ride_post_seats[value='3']"
    assert_select "#ride_post_exact_departure_time[aria-invalid='true']"
    assert_select "a[href='#ride_post_weekday_1']"
    assert_select "a[href='#ride_post_exact_departure_time']"
    assert_select "#ride_post_weekday_ids_error", text: "Days of the week must include at least one day"
    assert_select "#ride_post_exact_departure_time_error", text: "Departure time must be a valid time (HH:MM)"
  end

  test "an incomplete regular draft stays a private schedule" do
    assert_difference "RideSchedule.count", 1 do
      assert_no_difference "RidePost.count" do
        post ride_posts_url, params: { ride_type: "regular", intent: "draft", ride_post: { notes: "Planning the commute" } }
      end
    end
    schedule = @driver.ride_schedules.last
    assert_redirected_to schedule
    assert schedule.draft?
    assert_equal "Planning the commute", schedule.notes
  end
end
