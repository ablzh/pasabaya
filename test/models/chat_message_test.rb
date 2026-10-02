# frozen_string_literal: true

require "test_helper"

class ChatMessageTest < ActiveSupport::TestCase
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
    assert_includes msg.errors[:base], "Chat writes are closed 24 hours after trip departure"
  end

  test "purge_expired! removes messages older than 30 days" do
    @booking.update_columns(status: Booking.statuses[:accepted])

    old_msg = @ride.chat_messages.create!(user: @driver, body: "Old message")
    old_msg.update_columns(created_at: 35.days.ago)

    recent_msg = @ride.chat_messages.create!(user: @driver, body: "Recent message")

    assert_difference("ChatMessage.count", -1) do
      ChatMessage.purge_expired!(30.days.ago)
    end

    assert_not ChatMessage.exists?(old_msg.id)
    assert ChatMessage.exists?(recent_msg.id)
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
end
