require "test_helper"

class ChatsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @ride = ride_posts(:one)
    @driver = @ride.user
    @passenger = users(:two)
    bookings(:one).update_columns(status: Booking.statuses[:accepted])
  end

  test "participant sees route latest preview and discussion link" do
    @ride.chat_messages.create!(user: @driver, body: "Meet beside the library")
    sign_in_as(@passenger)

    get "/chats"

    assert_response :success
    assert_select "h1", text: "Chats"
    assert_select "a[href=?]", ride_post_path(@ride, tab: "chat") do
      assert_select "p", text: "Meet beside the library"
      assert_select "time[datetime]"
      assert_select "h2", text: /#{@ride.origin.name}.*#{@ride.destination.name}/
    end
  end
  test "retained conversation is labeled read-only after the sending window" do
    @ride.chat_messages.create!(user: @driver, body: "Pickup confirmed")
    @ride.update_columns(departure_time: 2.days.ago, status: RidePost.statuses[:completed])
    sign_in_as(@passenger)

    get chats_url

    assert_select "a[href=?]", ride_post_path(@ride, tab: "chat") do
      assert_select "span", text: "Read-only"
      assert_select "p", text: "Pickup confirmed"
    end
  end

  test "nonparticipant has helpful empty state and guest must sign in" do
    bookings(:one).update_columns(status: Booking.statuses[:pending])
    ride_posts(:two).destroy!
    sign_in_as(@passenger)

    get chats_url
    assert_response :success
    assert_select "p", text: "No trip conversations yet. Chats appear when you drive or join a confirmed trip."
    assert_select "a[href=?]", ride_posts_path, text: "Find a ride"

    delete session_url
    get chats_url
    assert_redirected_to new_session_url
  end

  test "signed-in navigation links to chats" do
    sign_in_as(@passenger)
    get root_url
    assert_select "a[href=?]", chats_path, text: "Chats"
  end

  test "inbox and direct navigation hide previews when participation or audience access is lost" do
    @ride.chat_messages.create!(user: @driver, body: "Private rendezvous")
    sign_in_as(@passenger)

    [ :pending, :declined, :canceled ].each do |status|
      bookings(:one).update_columns(status: Booking.statuses[status])
      get chats_url
      assert_not_includes response.body, "Private rendezvous"
      get ride_post_url(@ride, tab: "chat")
      assert_not_includes response.body, "Private rendezvous"
    end

    bookings(:one).update_columns(status: Booking.statuses[:accepted])
    @ride.update_columns(visibility: RidePost.visibilities[:hub_only], community_id: communities(:two).id)
    community_memberships(:two).update_columns(revoked_at: Time.current)
    get chats_url
    assert_not_includes response.body, "Private rendezvous"
    get ride_post_url(@ride, tab: "chat")
    assert_redirected_to ride_posts_url

    @ride.update_columns(visibility: RidePost.visibilities[:public_ride])
    @passenger.update_columns(banned_at: Time.current)
    get chats_url
    assert_not_includes response.body, "Private rendezvous"
    get ride_post_url(@ride, tab: "chat")
    assert_not_includes response.body, "Private rendezvous"
  end

  test "latest message refreshes preview and moves conversation to top" do
    ride_posts(:two).destroy!
    other = @ride.dup
    other.save!
    Booking.create!(ride_post: other, passenger: @passenger, status: :accepted)
    travel_to 2.minutes.ago do
      @ride.chat_messages.create!(user: @driver, body: "Older pickup")
    end
    travel_to 1.minute.ago do
      other.chat_messages.create!(user: @driver, body: "Recent pickup")
    end
    sign_in_as(@passenger)
    get chats_url
    assert_select "a[href*='tab=chat']" do |entries|
      assert_equal ride_post_path(other, tab: "chat"), entries.first["href"]
    end

    post ride_post_chat_messages_url(@ride), params: { chat_message: { body: "Updated pickup" } }
    get chats_url
    assert_select "a[href*='tab=chat']" do |entries|
      assert_equal ride_post_path(@ride, tab: "chat"), entries.first["href"]
      assert_includes entries.first.text, "Updated pickup"
    end
    assert_not_includes response.body, "Older pickup"
  end

  test "inbox query count stays constant as accessible public and hub conversations grow" do
    @ride.chat_messages.create!(user: @driver, body: "First pickup")
    sign_in_as(@passenger)
    get chats_url
    baseline = inbox_query_count

    Prosopite.pause do
      4.times do |index|
        ride = @ride.dup
        ride.save!
        Booking.create!(ride_post: ride, passenger: @passenger, status: :accepted)
        ride.chat_messages.create!(user: @driver, body: "Pickup #{index}")
        ride.update_columns(visibility: RidePost.visibilities[:hub_only], community_id: communities(:two).id) if index.even?
      end
    end

    assert_equal baseline, inbox_query_count
    assert_select "a[href*='tab=chat']", count: 6
  end

  private

  def inbox_query_count
    count = 0
    subscriber = ->(_name, _start, _finish, _id, payload) do
      count += 1 if payload[:sql].match?(/\ASELECT/i) && payload[:name] != "SCHEMA"
    end
    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { get chats_url }
    count
  end

end
