require "test_helper"

class ReadMarkerRaceTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  setup do
    @ride = ride_posts(:one)
    @driver = users(:one)
    @passenger = users(:two)
    bookings(:one).update_columns(status: Booking.statuses[:accepted])
    @older = @ride.chat_messages.create!(user: @driver, body: "First")
    @newer = @ride.chat_messages.create!(user: @driver, body: "Second")
  end

  test "a newer reading update arriving during an older update never regresses progress" do
    state = ChatReadState.create!(user: @passenger, ride_post: @ride)
    injected = false
    observer = ->(_name, _start, _finish, _id, payload) do
      if !injected && payload[:sql].include?('"chat_read_states"')
        injected = true
        state.update_columns(last_read_message_id: @newer.id)
      end
    end
    ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
      ChatReadState.mark_read!(user: @passenger, ride_post: @ride, message_id: @older.id)
    end
    assert injected
    assert_equal @newer.id, state.reload.last_read_message_id
  end

  test "author reply preserves unseen messages until explicit reading updates the badge on other devices" do
    @ride.chat_messages.create!(user: @passenger, body: "Question")
    assert_equal 1, @driver.unread_chats_count
    stream = Turbo::StreamsChannel.send(:stream_name_from, [ @driver, :notifications ])
    chats_stream = Turbo::StreamsChannel.send(:stream_name_from, [ @driver, :chats ])
    answer = nil
    assert_broadcasts(chats_stream, 1) do
      assert_broadcasts(stream, 0) do
        answer = @ride.chat_messages.create!(user: @driver, body: "Answer")
      end
    end
    assert_equal 1, @driver.unread_chats_count

    ChatReadState.mark_read!(user: @driver, ride_post: @ride, message_id: @newer.id)
    assert_equal 1, @driver.unread_chats_count, "reading older history must preserve the unseen question"
    assert_broadcasts(stream, 1) do
      assert ChatReadState.mark_read!(user: @driver, ride_post: @ride, message_id: answer.id)
    end
    assert_equal 0, @driver.unread_chats_count
    assert_includes broadcasts(stream).last, "data-chat"
  end
end
