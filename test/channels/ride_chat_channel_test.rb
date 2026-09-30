# frozen_string_literal: true

require "test_helper"

class RideChatChannelTest < ActionCable::Channel::TestCase
  setup do
    @ride = ride_posts(:one)
    @driver = @ride.user
    @passenger = users(:two)
    @booking = bookings(:one)
  end

  test "subscribes when user is driver and stream is verified" do
    stub_connection current_user: @driver
    signed = Turbo::StreamsChannel.signed_stream_name([ @ride, :chat ])

    subscribe signed_stream_name: signed
    assert subscription.confirmed?
  end

  test "subscribes when user is confirmed passenger" do
    @booking.update_columns(status: Booking.statuses[:accepted])
    stub_connection current_user: @passenger
    signed = Turbo::StreamsChannel.signed_stream_name([ @ride, :chat ])

    subscribe signed_stream_name: signed
    assert subscription.confirmed?
  end

  test "rejects subscription when user is not confirmed passenger or driver" do
    stub_connection current_user: @passenger
    signed = Turbo::StreamsChannel.signed_stream_name([ @ride, :chat ])

    subscribe signed_stream_name: signed
    assert subscription.rejected?
  end

  test "rejects subscription when signed stream name is invalid" do
    stub_connection current_user: @driver

    subscribe signed_stream_name: "tampered_stream_name"
    assert subscription.rejected?
  end

  test "stops transmission and rejects subscription when passenger booking is canceled" do
    @booking.update_columns(status: Booking.statuses[:accepted])
    stub_connection current_user: @passenger
    signed = Turbo::StreamsChannel.signed_stream_name([ @ride, :chat ])

    subscribe signed_stream_name: signed
    assert subscription.confirmed?

    # Cancel the booking
    @booking.update_columns(status: Booking.statuses[:canceled])

    # Attempt delivery
    subscription.deliver_or_reject(@ride, signed, "<div>hello</div>")

    # The subscription should not transmit the message to the canceled user
    assert_empty transmissions
    assert subscription.rejected?
  end

  test "subscribes with ActiveSupport::JSON coder so broadcasts deliver unescaped HTML" do
    called_with_coder = nil
    active_handler = nil

    interceptor = Module.new do
      define_method(:stream_from) do |stream, *args, coder: nil, &blk|
        called_with_coder = coder
        active_handler = coder ? ->(msg) { blk.call(coder.decode(msg)) } : blk
        super(stream, *args)
      end
    end

    ActionCable::Channel::ChannelStub.prepend(interceptor)

    stub_connection current_user: @driver
    signed = Turbo::StreamsChannel.signed_stream_name([ @ride, :chat ])
    subscribe signed_stream_name: signed
    assert_equal ActiveSupport::JSON, called_with_coder

    html_content = %(<turbo-stream action="append" target="chat_messages_list"><template><div>Hello</div></template></turbo-stream>)
    raw_payload = ActiveSupport::JSON.encode(html_content)
    active_handler.call(raw_payload)

    assert_equal 1, transmissions.size
    assert_equal html_content, transmissions.last
  end

  test "stops transmission and rejects subscription when user is banned after connecting" do
    @booking.update_columns(status: Booking.statuses[:accepted])
    stub_connection current_user: @passenger
    signed = Turbo::StreamsChannel.signed_stream_name([ @ride, :chat ])

    subscribe signed_stream_name: signed
    assert subscription.confirmed?

    # Ban the user in another request
    @passenger.update_columns(banned_at: Time.current)

    # Attempt delivery
    subscription.deliver_or_reject(@ride, signed, "<div>hello</div>")

    assert_empty transmissions
    assert subscription.rejected?
  end
end
