require "test_helper"

class NotificationsChannelTest < ActionCable::Channel::TestCase
  setup do
    @user = users(:one)
    @session = @user.sessions.create!
    stub_connection current_user: @user, current_session: @session
  end

  test "queued chat previews recheck access before delivery" do
    ride = ride_posts(:one)
    bookings(:one).update_columns(status: Booking.statuses[:accepted], accepted_at: 1.hour.ago)
    ride.update_columns(visibility: RidePost.visibilities[:hub_only], community_id: communities(:one).id)
    subscribe signed_stream_name: Turbo::StreamsChannel.signed_stream_name([ @user, :notifications ])
    payload = %(<turbo-stream action="append"><template><div data-ride-id="#{ride.id}">Private pickup</div></template></turbo-stream>)

    subscription.deliver_or_reject(payload)
    assert_equal 1, transmissions.size
    community_memberships(:one).update_columns(revoked_at: Time.current)
    subscription.deliver_or_reject(payload)
    assert_equal 1, transmissions.size, "revoked hub access must suppress a queued preview"

    community_memberships(:one).update_columns(revoked_at: nil)
    travel_to ride.chat_history_unavailable_at do
      subscription.deliver_or_reject(payload)
      assert_equal 1, transmissions.size, "expired history must suppress a queued preview"
    end
  end

  test "queued chat previews are suppressed after participation is lost or the ride is removed" do
    passenger = users(:two)
    session = passenger.sessions.create!
    stub_connection current_user: passenger, current_session: session
    ride = ride_posts(:one)
    booking = bookings(:one)
    booking.update_columns(status: Booking.statuses[:accepted], accepted_at: 1.hour.ago)
    subscribe signed_stream_name: Turbo::StreamsChannel.signed_stream_name([ passenger, :notifications ])
    payload = %(<turbo-stream action="append"><template><div data-ride-id="#{ride.id}">Private pickup</div></template></turbo-stream>)

    subscription.deliver_or_reject(payload)
    assert_equal 1, transmissions.size
    booking.update_columns(status: Booking.statuses[:canceled])
    subscription.deliver_or_reject(payload)
    assert_equal 1, transmissions.size

    ride.destroy!
    subscription.deliver_or_reject(payload)
    assert_equal 1, transmissions.size
  end

  test "queued route alert HTML is not transmitted after recipient loses hub access" do
    ride = ride_posts(:one)
    ride.update_columns(visibility: RidePost.visibilities[:hub_only], community_id: communities(:two).id)
    notification = Notification.create!(recipient: @user, notifiable: ride, event_name: "route.alert", delivery_key: "queued-private-route")
    subscribe signed_stream_name: Turbo::StreamsChannel.signed_stream_name([ @user, :notifications ])
    assert subscription.confirmed?

    subscription.deliver_or_reject(%(<turbo-stream action="append"><template><div data-route-alert-id="#{notification.id}">Private route</div></template></turbo-stream>))
    assert_empty transmissions
  end

  test "only subscribes to the authenticated user's notifications" do
    subscribe signed_stream_name: Turbo::StreamsChannel.signed_stream_name([ @user, :notifications ])
    assert subscription.confirmed?
  end

  test "subscribes to authenticated user's chats stream" do
    subscribe signed_stream_name: Turbo::StreamsChannel.signed_stream_name([ @user, :chats ])
    assert subscription.confirmed?
  end

  test "rejects another user's signed notification stream" do
    subscribe signed_stream_name: Turbo::StreamsChannel.signed_stream_name([ users(:two), :notifications ])
    assert subscription.rejected?
  end

  test "rejects another user's signed chats stream" do
    subscribe signed_stream_name: Turbo::StreamsChannel.signed_stream_name([ users(:two), :chats ])
    assert subscription.rejected?
  end

  test "revoked sessions cannot receive notifications" do
    subscribe signed_stream_name: Turbo::StreamsChannel.signed_stream_name([ @user, :notifications ])
    @session.destroy!
    subscription.deliver_or_reject("private notification")
    assert_empty transmissions
    assert subscription.rejected?
  end

  test "banned users cannot receive notifications" do
    subscribe signed_stream_name: Turbo::StreamsChannel.signed_stream_name([ @user, :notifications ])
    @user.update_columns(banned_at: Time.current)
    subscription.deliver_or_reject("private notification")
    assert_empty transmissions
    assert subscription.rejected?
  end

  test "deleted users cannot subscribe even when a session survives" do
    @user.update_columns(deleted_at: Time.current)
    subscribe signed_stream_name: Turbo::StreamsChannel.signed_stream_name([ @user, :notifications ])
    assert subscription.rejected?
  end

  test "deleted users cannot receive notifications through an existing stream" do
    subscribe signed_stream_name: Turbo::StreamsChannel.signed_stream_name([ @user, :notifications ])
    @user.update_columns(deleted_at: Time.current)
    subscription.deliver_or_reject("private notification")
    assert_empty transmissions
    assert subscription.rejected?
  end
end
