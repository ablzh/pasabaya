# frozen_string_literal: true

require "test_helper"

class ChatMessageTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  setup do
    @ride = ride_posts(:one)
    @driver = @ride.user
    @passenger = users(:two)
    @booking = bookings(:one)
  end

  test "authorized driver can send message when booking is accepted" do
    @booking.update_columns(status: Booking.statuses[:accepted])

    msg = @ride.chat_messages.build(user: @driver, body: "Leaving at 7:00 AM sharp.")
    assert msg.valid?
    assert msg.save
  end

  test "authorized confirmed passenger can send message" do
    @booking.update_columns(status: Booking.statuses[:accepted])

    msg = @ride.chat_messages.build(user: @passenger, body: "Got it, I will be at the gate.")
    assert msg.valid?
    assert msg.save
  end

  test "unconfirmed or stranger user cannot send message" do
    # Booking is pending (not accepted)
    msg = @ride.chat_messages.build(user: @passenger, body: "Can I join?")
    assert_not msg.valid?
    assert_includes msg.errors[:base], "Only the driver and confirmed passengers can participate in trip chat"
  end

  test "cannot write message more than 24 hours after departure" do
    @booking.update_columns(status: Booking.statuses[:accepted])
    @ride.update_columns(departure_time: 25.hours.ago, expected_arrival_at: 23.hours.ago)

    msg = @ride.chat_messages.build(user: @driver, body: "Thanks for the ride!")
    assert_not msg.valid?
    assert_includes msg.errors[:base], "Chat writes are closed 24 hours after the booking cutoff"
  end

  test "purge_expired! removes all messages in expired conversations and preserves retained conversations" do
    @booking.update_columns(status: Booking.statuses[:accepted])

    expired_old_msg = @ride.chat_messages.create!(user: @driver, body: "Expired old message")
    expired_recent_msg = @ride.chat_messages.create!(user: @driver, body: "Expired recent message")
    # Expired ride: cutoff was 35 days ago (history unavailable after 31 days)
    @ride.update_columns(departure_time: 35.days.ago, expected_arrival_at: 34.days.ago)

    # Retained ride: cutoff was 2 days ago (history retained for 29 more days)
    retained_ride = ride_posts(:two)
    Booking.create!(ride_post: retained_ride, passenger: users(:one), status: :accepted)
    retained_msg = retained_ride.chat_messages.create!(user: retained_ride.user, body: "Retained message")
    retained_ride.update_columns(departure_time: 2.days.ago, expected_arrival_at: 1.day.ago)

    assert_difference("ChatMessage.count", -2) do
      ChatMessage.purge_expired!
    end

    assert_not ChatMessage.exists?(expired_old_msg.id)
    assert_not ChatMessage.exists?(expired_recent_msg.id)
    assert ChatMessage.exists?(retained_msg.id)
  end

  test "creating a chat message broadcasts toast to participants" do
    @booking.update_columns(status: Booking.statuses[:accepted])

    broadcasts = []
    original_broadcast = Turbo::StreamsChannel.method(:broadcast_append_to)
    Turbo::StreamsChannel.define_singleton_method(:broadcast_append_to) do |stream, *args, **kwargs|
      broadcasts << { stream: stream, kwargs: kwargs }
      original_broadcast.call(stream, *args, **kwargs)
    end

    begin
      @ride.chat_messages.create!(user: @driver, body: "See you at the pickup point!")
      toast_broadcast = broadcasts.find { |b| b[:stream] == [ @passenger, :notifications ] && b[:kwargs][:target] == "toast-container" }
      assert_not_nil toast_broadcast
      assert_equal "chat_messages/toast", toast_broadcast[:kwargs][:partial]
      assert_equal @ride.id, toast_broadcast[:kwargs][:locals][:ride_post_id]
      assert_includes toast_broadcast[:kwargs][:locals][:title], @driver.first_name
    ensure
      Turbo::StreamsChannel.define_singleton_method(:broadcast_append_to, original_broadcast)
    end
  end

  test "chat previews exclude banned participants" do
    @booking.update_columns(status: Booking.statuses[:accepted])
    @passenger.update_columns(banned_at: Time.current)
    stream = Turbo::StreamsChannel.send(:stream_name_from, [ @passenger, :notifications ])
    assert_no_broadcasts(stream) do
      @ride.chat_messages.create!(user: @driver, body: "Private chat")
    end
  end
  test "new messages refresh participant inboxes without broadcasting private previews" do
    @booking.update_columns(status: Booking.statuses[:accepted])
    stream = Turbo::StreamsChannel.send(:stream_name_from, [ @passenger, :chats ])
    driver_stream = Turbo::StreamsChannel.send(:stream_name_from, [ @driver, :chats ])

    assert_broadcasts(stream, 1) do
      assert_broadcasts(driver_stream, 1) do
        @ride.chat_messages.create!(user: @driver, body: "Private meeting details")
      end
    end
    payload = broadcasts(stream).last
    assert_includes payload, 'action=\"refresh\"'
    assert_not_includes payload, "Private meeting details"
  end
end
