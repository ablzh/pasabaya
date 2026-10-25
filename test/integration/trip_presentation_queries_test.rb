require "test_helper"

class TripPresentationQueriesTest < ActionDispatch::IntegrationTest
  test "search profile and hub cards retain the original creation dates across regular offers" do
    driver = users(:one)
    origin = locations(:one)
    destination = locations(:two)
    community = communities(:one)
    date = Date.tomorrow
    offers = Prosopite.pause do
      2.times.map do |index|
        source = driver.ride_posts.create!(status: :draft, created_at: (index + 1).months.ago.change(usec: 0))
        schedule = driver.ride_schedules.create!(source_ride_post: source, origin: origin,
          destination: destination, community: community, weekdays_mask: 1 << date.wday,
          departure_choice: :flexible, seats: 3, status: :active, created_at: 2.weeks.ago)
        ride = schedule.ride_posts.create!(schedule.ride_attributes(date).merge(schedule_date: date))
        [ ride, source.created_at ]
      end
    end
    sign_in_as(users(:two))

    [ route_rides_url(origin_slug: origin.slug, destination_slug: destination.slug),
      user_url(driver), community_url(community) ].each do |url|
      get url
      assert_response :success
      offers.each do |ride, created_at|
        assert_select "#ride_post_#{ride.id} time[datetime=?]", created_at.iso8601
      end
    end
  end

  test "trip details do not load inactive booking history for any viewer" do
    ride = ride_posts(:one)
    booking = bookings(:one)
    outsider = User.create!(email_address: "trip-outsider@example.test", password: "password", first_name: "Other", last_name: "Passenger")
    attributes = booking.attributes.except("id").merge("accepted_at" => 2.days.ago, "canceled_at" => 1.day.ago)
    Booking.insert_all!(Array.new(1000) { |index| attributes.merge("status" => Booking.statuses.fetch(%w[declined canceled expired][index % 3])) })

    assert_equal 0, trip_booking_record_count(ride), "Guests do not need booking records"
    sign_in_as(outsider)
    assert_equal 0, trip_booking_record_count(ride), "Nonparticipants do not need inactive requests"

    sign_in_as(booking.passenger)
    assert_operator trip_booking_record_count(ride), :<=, 1
    assert_select "form[action='#{cancel_booking_path(booking)}']"

    sign_in_as(ride.user)
    assert_operator trip_booking_record_count(ride), :<=, 1
    assert_select "#driver_requests_ride_post_#{ride.id} a[href='#{user_path(booking.passenger)}']"

    Bookings::AcceptService.call(booking, actor: ride.user)
    sign_in_as(booking.passenger)
    assert_operator trip_booking_record_count(ride), :<=, 3
    assert_select "#trip-chat-pane"

    RidePosts::CancelService.call(ride, actor: ride.user)
    assert_operator trip_booking_record_count(ride), :<=, 3
    assert_select "#trip-chat-pane"
    assert_select ".chat-header p", text: /2 participants/
  end

  test "passenger avatars use a fixed number of attachment and blob queries" do
    ride = ride_posts(:one)
    users(:two).avatar.attach(io: StringIO.new(Vips::Image.black(2, 2).pngsave_buffer), filename: "passenger.png", content_type: "image/png")
    sign_in_as(users(:one))
    get ride_post_url(ride)
    baseline = avatar_query_count(ride)

    passengers = Prosopite.pause do
      4.times.map do |index|
        passenger = User.create!(email_address: "trip-passenger-#{index}@example.test", password: "password", first_name: "Passenger", last_name: index.to_s)
        passenger.avatar.attach(io: StringIO.new(Vips::Image.black(2, 2).pngsave_buffer), filename: "passenger-#{index}.png", content_type: "image/png")
        Booking.create!(ride_post: ride, passenger: passenger, status: index.even? ? :accepted : :pending)
        passenger
      end
    end

    assert_equal baseline, avatar_query_count(ride)
    assert_response :success
    passengers.each do |passenger|
      assert_select "a[href='#{user_path(passenger)}']", text: "#{passenger.first_name} #{passenger.last_name}"
    end
    assert_select "h3", text: /Pending Requests \(3\)/
    assert_select "h3", text: /Confirmed Passengers \(2 \/ 3\)/
  end

  test "large driver history is loaded one bounded page in deterministic order" do
    ride = ride_posts(:one)
    attributes = ride.attributes.except("id").merge("status" => RidePost.statuses[:completed], "departure_time" => 3.days.ago, "departure_date" => 3.days.ago.to_date, "created_at" => 4.days.ago.change(usec: 0))
    history_ids = RidePost.insert_all!(Array.new(205) { attributes.dup }, returning: %w[id]).rows.flatten.sort.reverse
    sign_in_as(users(:one))

    loaded = []
    observer = ->(_name, _start, _finish, _id, payload) { loaded << payload[:record_count] if payload[:class_name] == "RidePost" }
    ActiveSupport::Notifications.subscribed(observer, "instantiation.active_record") { get trips_url }

    assert_response :success
    assert_equal history_ids.first(20), css_select("#profile-history [id^='ride_post_']").map { |node| node["id"].delete_prefix("ride_post_").to_i }
    assert_operator loaded.sum, :<=, 21, "History must not instantiate all 205 records (plus the current offer)"
    assert_select "#history_page-pagination a[rel='next']"

    get trips_url(history_page: 2)
    assert_equal history_ids.slice(20, 20), css_select("#profile-history [id^='ride_post_']").map { |node| node["id"].delete_prefix("ride_post_").to_i }
    assert_select "#history_page-pagination a[rel='prev']"
    assert_select "#profile-drafts [id^='ride_post_']", count: 0

    visited = history_ids.first(40)
    (3..11).each do |page|
      get trips_url(history_page: page)
      visited.concat(css_select("#profile-history [id^='ride_post_']").map { |node| node["id"].delete_prefix("ride_post_").to_i })
    end
    assert_equal history_ids, visited, "Equal creation timestamps must not duplicate or omit rides between pages"
    assert_select "#history_page-pagination a[rel='next']", count: 0
  end

  test "joined trip history is bounded and retains canceled accepted participation" do
    ride = ride_posts(:one)
    attributes = ride.attributes.except("id").merge("status" => RidePost.statuses[:canceled], "departure_time" => 3.days.ago, "departure_date" => 3.days.ago.to_date, "canceled_at" => 3.days.ago)
    ride_ids = RidePost.insert_all!(Array.new(45) { attributes.dup }, returning: %w[id]).rows.flatten
    booking_attributes = bookings(:one).attributes.except("id").merge("status" => Booking.statuses[:canceled], "accepted_at" => 4.days.ago, "canceled_at" => 3.days.ago, "created_at" => 4.days.ago.change(usec: 0))
    booking_ids = Booking.insert_all!(ride_ids.map { |id| booking_attributes.merge("ride_post_id" => id) }, returning: %w[id]).rows.flatten.sort.reverse
    sign_in_as(users(:two))

    get trips_url(tab: "bookings")
    assert_select "#profile-bookings [id^='booking_']", count: 20
    assert_select "#bookings_page-pagination a[rel='next']"
    assert_select "#profile-history", count: 0

    get trips_url(tab: "bookings", bookings_page: 2)
    assert_equal booking_ids.slice(19, 20), css_select("#profile-bookings [id^='booking_']").map { |node| node["id"].delete_prefix("booking_").to_i }
    assert_select "#profile-bookings a[href='#{ride_post_path(RidePost.find(ride_ids.first))}']", count: 0
    assert Booking.where(id: booking_ids).all? { |booking| booking.canceled? && booking.accepted_at.present? }
  end

  private

  def trip_booking_record_count(ride)
    count = 0
    observer = ->(_name, _start, _finish, _id, payload) { count += payload[:record_count] if payload[:class_name] == "Booking" }
    ActiveSupport::Notifications.subscribed(observer, "instantiation.active_record") { get ride_post_url(ride) }
    assert_response :success
    count
  end

  def avatar_query_count(ride)
    count = 0
    observer = ->(_name, _start, _finish, _id, payload) do
      count += 1 if payload[:sql].match?(/\ASELECT.*FROM "active_storage_(attachments|blobs)"/i) && payload[:name] != "SCHEMA"
    end
    ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
      ActiveRecord::Base.uncached { get ride_post_url(ride) }
    end
    count
  end
end
