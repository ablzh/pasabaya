# frozen_string_literal: true

require "test_helper"

class ChatReadStateTest < ActiveSupport::TestCase
  setup do
    @ride = ride_posts(:one)
    @driver = @ride.user
    @passenger = users(:two)
    bookings(:one).update_columns(status: Booking.statuses[:accepted], accepted_at: 1.day.ago)
  end

  test "unread_chats_count counts unread conversations, not total messages" do
    assert_equal 0, @passenger.unread_chats_count

    # Driver sends 3 messages in the same conversation
    Prosopite.pause do
      3.times do |i|
        @ride.chat_messages.create!(user: @driver, body: "Message #{i}")
      end
    end

    # Should count as 1 unread conversation, not 3
    assert_equal 1, @passenger.unread_chats_count

    # Driver sends own message: driver does not see conversation as unread
    assert_equal 0, @driver.unread_chats_count
  end

  test "user own messages do not mark conversation unread" do
    assert_equal 0, @driver.unread_chats_count
    @ride.chat_messages.create!(user: @driver, body: "Driver's own message")
    assert_equal 0, @driver.unread_chats_count

    # Passenger sends message
    @ride.chat_messages.create!(user: @passenger, body: "Passenger's reply")
    assert_equal 1, @driver.unread_chats_count
    assert_equal 0, @passenger.unread_chats_count
  end

  test "mark_read! updates last_read_message_id and clears unread count" do
    msg = @ride.chat_messages.create!(user: @driver, body: "Hello passenger")
    assert_equal 1, @passenger.unread_chats_count

    assert ChatReadState.mark_read!(user: @passenger, ride_post: @ride, message_id: msg.id)
    assert_equal 0, @passenger.unread_chats_count

    read_state = @passenger.chat_read_states.find_by(ride_post: @ride)
    assert_equal msg.id, read_state.last_read_message_id
  end

  test "racing incoming message after read update remains unread" do
    msg1 = @ride.chat_messages.create!(user: @driver, body: "Message 1")
    msg2 = @ride.chat_messages.create!(user: @driver, body: "Message 2")

    # Passenger was viewing up to msg2, marks msg2 as read
    ChatReadState.mark_read!(user: @passenger, ride_post: @ride, message_id: msg2.id)
    assert_equal 0, @passenger.unread_chats_count

    # New message arrives racing with or after read update
    msg3 = @ride.chat_messages.create!(user: @driver, body: "Message 3 (racing)")
    assert_equal 1, @passenger.unread_chats_count

    # A delayed or stale read request with older message ID does not downgrade read state
    assert_not ChatReadState.mark_read!(user: @passenger, ride_post: @ride, message_id: msg1.id)
    read_state = @passenger.chat_read_states.find_by(ride_post: @ride)
    assert_equal msg2.id, read_state.last_read_message_id
    assert_equal 1, @passenger.unread_chats_count
  end

  test "expired conversation does not leave phantom unread count" do
    @ride.chat_messages.create!(user: @driver, body: "Message before expiration")
    assert_equal 1, @passenger.unread_chats_count

    # Expire chat history (past 30 days retention)
    @ride.update_columns(departure_time: 35.days.ago, expected_arrival_at: 34.days.ago)
    assert @ride.chat_expired?

    # Expired chat must not contribute to unread count
    assert_equal 0, @passenger.unread_chats_count
  end

  test "revoked community access does not leave phantom unread count" do
    @ride.chat_messages.create!(user: @driver, body: "Hub private message")
    @ride.update_columns(visibility: RidePost.visibilities[:hub_only], community_id: communities(:two).id)
    assert_equal 1, @passenger.unread_chats_count

    # Revoke passenger's community membership
    community_memberships(:two).update_columns(revoked_at: Time.current)
    assert_equal 0, @passenger.unread_chats_count
  end

  test "banned or unaccepted user does not have unread counts" do
    @ride.chat_messages.create!(user: @driver, body: "Trip message")
    assert_equal 1, @passenger.unread_chats_count

    # If booking was never accepted
    bookings(:one).update_columns(status: Booking.statuses[:pending], accepted_at: nil)
    assert_equal 0, @passenger.unread_chats_count

    # If passenger is banned
    bookings(:one).update_columns(status: Booking.statuses[:accepted], accepted_at: 1.day.ago)
    @passenger.update_columns(banned_at: Time.current)
    assert_equal 0, @passenger.unread_chats_count
  end
end
