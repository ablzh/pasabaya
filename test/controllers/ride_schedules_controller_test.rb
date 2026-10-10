require "test_helper"

class RideSchedulesControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.zone.local(2026, 10, 8, 10)
    @driver = users(:one)
    sign_in_as @driver
    @origin = locations(:one)
    @destination = locations(:two)
    @params = { origin_id: @origin.id, destination_id: @destination.id, weekday_ids: [ "1", "2" ], departure_choice: "exact_time", exact_departure_time: "08:00", seats: 3 }
  end

  teardown { travel_back }

  test "publishing creates independent dates and search groups the schedule after filtering" do
    post ride_posts_url, params: { ride_type: "regular", ride_post: @params, intent: "publish" }
    schedule = @driver.ride_schedules.last
    assert_redirected_to schedule
    assert_equal 4, schedule.ride_posts.count
    get ride_posts_url(origin_id: locations(:one).id)
    assert_response :success
    assert_select "#ride_posts [id^='ride_post_']", count: 2
    assert_select "a[href='#{ride_schedule_path(schedule)}']", count: 1
    date = Date.new(2026, 10, 19)
    get ride_posts_url(origin_id: locations(:one).id, departure_date: date.to_s)
    assert_response :success
    assert_select "#ride_posts [id^='ride_post_']", count: 1
    assert_select "a[href='#{ride_post_path(schedule.ride_posts.find_by!(departure_date: date))}']", count: 1
    assert_equal 2, RidePost.popular_routes.find { |route| route[:origin].id == locations(:one).id }[:count]
  end

  test "old undated draft conversion preserves the original and requires confirmation" do
    source = @driver.ride_posts.create!(status: :draft, origin: @origin, destination: @destination, seats: 3, notes: "Legacy flexible offer")
    get new_ride_post_url(ride_type: "regular", source_ride_post_id: source.id)
    assert_response :success
    assert_select "textarea", text: "Legacy flexible offer"
    post ride_posts_url, params: { ride_type: "regular", ride_post: @params.merge(source_ride_post_id: source.id), intent: "publish" }
    assert_response :see_other
    assert source.reload.draft?
    assert_nil source.departure_date
    assert_equal 1, RideSchedule.where(source_ride_post_id: source.id).count
    post ride_posts_url, params: { ride_type: "regular", ride_post: @params.merge(source_ride_post_id: source.id), intent: "publish" }
    assert_response :unprocessable_content
    assert_equal 1, RideSchedule.where(source_ride_post_id: source.id).count
  end

  test "invalid publication reports errors without creating partial departures" do
    assert_no_difference [ "RideSchedule.count", "RidePost.count" ] do
      post ride_posts_url, params: { ride_type: "regular", ride_post: @params.merge(weekday_ids: []), intent: "publish" }
    end
    assert_response :unprocessable_content
    assert_select "#ride_post_weekday_ids_error", text: /\S/
  end

  test "other users cannot change the schedule or convert another driver draft" do
    post ride_posts_url, params: { ride_type: "regular", ride_post: @params, intent: "publish" }
    schedule = @driver.ride_schedules.last
    sign_in_as users(:two)
    patch pause_ride_schedule_url(schedule)
    assert_response :not_found
    assert schedule.reload.active?
    get new_ride_post_url(ride_type: "regular", source_ride_post_id: ride_posts(:one).id)
    assert_response :not_found
  end

  test "restricted schedule and its departures do not leak through search or direct links" do
    sign_in_as users(:two)
    post ride_posts_url, params: { ride_type: "regular", ride_post: @params.merge(ladies_only: true), intent: "publish" }
    schedule = users(:two).ride_schedules.last
    sign_out
    get ride_schedule_url(schedule)
    assert_response :forbidden
    get ride_posts_url(origin_id: locations(:one).id)
    assert_response :success
    assert_select "a[href='#{ride_schedule_path(schedule)}']", count: 0
    get ride_post_url(schedule.ride_posts.first)
    assert_redirected_to ride_posts_url
    sign_in_as @driver
    post ride_post_bookings_url(schedule.ride_posts.first), params: { booking: {} }
    assert_not Booking.exists?(ride_post: schedule.ride_posts.first, passenger: @driver)
  end

  test "the nearest open departure is listed when an earlier date is manually closed" do
    post ride_posts_url, params: { ride_type: "regular", ride_post: @params, intent: "publish" }
    schedule = @driver.ride_schedules.last
    first = schedule.ride_posts.order(:departure_date).first
    RidePosts::CloseRequestsService.call(first, actor: @driver)
    get ride_posts_url(origin_id: @origin.id)
    assert_response :success
    assert_select "#ride_post_#{first.id}", count: 0
    assert_select "a[href='#{ride_schedule_path(schedule)}']", count: 1
  end

  test "popular routes count schedule exceptions on both routes without counting every date" do
    post ride_posts_url, params: { ride_type: "regular", ride_post: @params, intent: "publish" }
    schedule = @driver.ride_schedules.last
    first = schedule.ride_posts.order(:departure_date).first
    Bookings::CreateService.call(ride_post: first, passenger: users(:two))
    RideSchedules::ConfigureService.call(schedule: schedule, actor: @driver, attributes: { origin: @destination, destination: @origin })
    counts = RidePost.popular_routes.to_h { |route| [ [ route[:origin].id, route[:destination].id ], route[:count] ] }
    assert_equal 2, counts[[ @origin.id, @destination.id ]]
    assert_equal 2, counts[[ @destination.id, @origin.id ]]
  end
end
