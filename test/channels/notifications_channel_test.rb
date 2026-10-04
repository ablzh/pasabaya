require "test_helper"

class NotificationsChannelTest < ActionCable::Channel::TestCase
  setup do
    @user = users(:one)
    @session = @user.sessions.create!
    stub_connection current_user: @user, current_session: @session
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
