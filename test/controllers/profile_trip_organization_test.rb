require "test_helper"

class ProfileTripOrganizationTest < ActionDispatch::IntegrationTest
  test "regular schedules stay grouped and only booked occurrences enter history" do
    driver = users(:one)
    origin = locations(:one)
    destination = locations(:two)
    source = RidePost.create!(user: driver, status: :draft)
    schedule = RideSchedule.create!(user: driver, source_ride_post: source, origin: origin, destination: destination,
      weekdays_mask: 127, seats: 3, departure_choice: :morning, status: :active)
    RideSchedules::MaterializeService.call(schedule)
    booked, empty = schedule.ride_posts.order(:departure_date).first(2)
    booking = Bookings::CreateService.call(ride_post: booked, passenger: users(:two))
    Bookings::AcceptService.call(booking, actor: driver)
    RidePost.where(id: [ booked.id, empty.id ]).update_all(status: RidePost.statuses[:completed])
    ride_posts(:one).update_columns(departure_time: 10.days.from_now, departure_date: 10.days.from_now.to_date)
    sign_in_as(driver)

    travel 3.days do
      get trips_url
    end

    assert_select "#profile-regular-rides a[href='#{ride_schedule_path(schedule)}']", count: 1
    assert_select "#profile-active-rides [id^='ride_post_']", count: 1
    assert_select "#profile-drafts #ride_post_#{source.id}", count: 0
    assert_select "#profile-history #ride_post_#{booked.id}"
    assert_select "#profile-history #ride_post_#{empty.id}", count: 0
    assert booking.reload.accepted?
    assert booking.accepted_at
  end

  test "profile pagination filters restricted offers before limiting the page" do
    driver = users(:one)
    ride = ride_posts(:one)
    attributes = ride.attributes.except("id")
    visible = RidePost.insert_all!(Array.new(5) { attributes.merge("created_at" => 1.day.ago) }, returning: %w[id]).rows.flatten
    restricted = RidePost.insert_all!(Array.new(25) { attributes.merge("visibility" => RidePost.visibilities[:hub_only], "community_id" => communities(:one).id) }, returning: %w[id]).rows.flatten
    sign_in_as(users(:two))

    get user_url(driver, history_page: 2)

    assert_select "#profile-active-rides [id^='ride_post_']", count: 6
    assert_select "#profile-history, #profile-drafts, #profile-departed-rides", count: 0
    assert_select "#posts_page-pagination", count: 0
    assert_select "#profile-active-rides #ride_post_#{visible.first}"
    assert_select "#profile-active-rides #ride_post_#{restricted.first}", count: 0
  end

  test "a converted draft stays hidden when its regular schedule is on another page" do
    owner = users(:one)
    source = RidePost.create!(user: owner, status: :draft)
    schedule = RideSchedule.create!(user: owner, source_ride_post: source, status: :draft, created_at: 1.day.ago)
    attributes = schedule.attributes.except("id").merge("source_ride_post_id" => nil, "created_at" => Time.current)
    RideSchedule.insert_all!(Array.new(20) { attributes.dup })
    sign_in_as(owner)

    get trips_url
    assert_select "#profile-drafts #ride_post_#{source.id}", count: 0
    assert_select "#profile-regular-rides #ride_schedule_#{schedule.id}", count: 0
    assert_select "#schedules_page-pagination a[rel='next']"

    get trips_url(schedules_page: 2)
    assert_select "#profile-regular-rides #ride_schedule_#{schedule.id}"
    assert_select "#profile-drafts #ride_post_#{source.id}", count: 0
  end

  test "invalid and oversized history pages remain bounded" do
    attributes = ride_posts(:one).attributes.except("id").merge("status" => RidePost.statuses[:completed])
    ids = RidePost.insert_all!(Array.new(21) { attributes.dup }, returning: %w[id]).rows.flatten.sort.reverse
    sign_in_as(users(:one))

    get trips_url(history_page: "invalid")
    assert_response :success
    assert_select "#profile-history [id^='ride_post_']", count: 20
    assert_select "#profile-history #ride_post_#{ids.first}"

    get trips_url(history_page: "9" * 50)
    assert_response :success
    assert_select "#profile-history [id^='ride_post_']", count: 1
    assert_select "#profile-history #ride_post_#{ids.last}"
    assert_select "#history_page-pagination a[rel='next']", count: 0
  end

  test "draft management publishes explicitly and reports incomplete or elapsed drafts" do
    ride = ride_posts(:one)
    sign_in_as(ride.user)
    ride.update_columns(status: RidePost.statuses[:draft])
    patch publish_ride_post_url(ride)
    assert_redirected_to user_url(ride.user)
    assert ride.reload.bookable?

    ride.update_columns(status: RidePost.statuses[:draft], origin_id: nil, destination_id: nil, departure_time: nil, departure_date: nil)
    patch publish_ride_post_url(ride)
    assert_redirected_to user_url(ride.user)
    assert ride.reload.draft?
    assert_predicate flash[:alert], :present?
    assert_predicate flash[:feedback_errors], :present?
    follow_redirect!
    assert_select "#profile-drafts #ride_post_#{ride.id} a[href='#{edit_ride_post_path(ride)}']"

    ride.update_columns(origin_id: locations(:one).id, destination_id: locations(:two).id, departure_time: 1.hour.ago, departure_date: Date.current)
    patch publish_ride_post_url(ride)
    assert ride.reload.draft?
    assert_predicate flash[:feedback_errors], :present?
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

  test "driver restrictions hide profile discovery without hiding existing trip management" do
    ride = ride_posts(:one)
    booking = bookings(:one)
    driver = users(:one)
    passenger = users(:two)
    Bookings::AcceptService.call(booking, actor: driver)
    remaining_seats = ride.reload.remaining_seats
    sign_in_as(passenger)

    get user_url(driver)
    assert_select "#profile-active-rides #ride_post_#{ride.id}"
    driver.update!(booking_freeze_until: 1.hour.from_now)
    get user_url(driver)
    assert_select "#ride_post_#{ride.id}", count: 0

    get trips_url(tab: "bookings")
    assert_response :success
    assert_select "a[href='#{ride_post_path(ride, tab: 'chat')}']"
    assert booking.reload.accepted?
    assert_equal remaining_seats, ride.reload.remaining_seats

    sign_in_as(driver)
    get trips_url
    assert_select "#profile-active-rides #ride_post_#{ride.id}"
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
    assert_predicate flash[:feedback_errors], :present?
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
    assert_select "#profile-drafts form[action='#{publish_ride_post_path(ride)}'] button[type='submit']"
    assert_select "#profile-drafts form[action='#{ride_post_path(ride)}'] input[name='_method'][value='delete']"

    ride.update_columns(status: RidePost.statuses[:completed], origin_id: locations(:one).id, destination_id: locations(:two).id, departure_time: 2.days.ago, departure_date: 2.days.ago.to_date)
    get user_url(owner)
    assert_select "#profile-history #ride_post_#{ride.id}", text: /Past/
    assert_select "#profile-history #ride_post_#{ride.id} a[href='#{ride_post_path(ride)}']"
    assert_select "#profile-active-rides #ride_post_#{ride.id}", count: 0
  end
end
