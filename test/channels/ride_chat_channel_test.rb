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
end
