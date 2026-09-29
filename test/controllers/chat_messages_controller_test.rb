# frozen_string_literal: true

require "test_helper"

class ChatMessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @ride = ride_posts(:one)
    @driver = @ride.user
    @passenger = users(:two)
    @booking = bookings(:one)
  end

  test "confirmed passenger can post chat message" do
    @booking.update_columns(status: Booking.statuses[:accepted])
    sign_in_as(@passenger)

    assert_difference -> { @ride.chat_messages.count } => 1 do
      post ride_post_chat_messages_url(@ride), params: {
        chat_message: { body: "I am at the meeting point" }
      }
    end

    assert_redirected_to ride_post_url(@ride)
    assert_equal "I am at the meeting point", @ride.chat_messages.last.body
  end

  test "unconfirmed user cannot post chat message" do
    # Booking is pending
    sign_in_as(@passenger)

    assert_no_difference "ChatMessage.count" do
      post ride_post_chat_messages_url(@ride), params: {
        chat_message: { body: "Unauthorized message" }
      }
    end

    assert_redirected_to ride_post_url(@ride)
  end

  test "unauthenticated user cannot post chat message" do
    post ride_post_chat_messages_url(@ride), params: {
      chat_message: { body: "Unauthenticated message" }
    }

    assert_redirected_to new_session_url
  end
end
