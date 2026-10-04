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

    assert_response :see_other
    assert_redirected_to ride_post_url(@ride, tab: "chat")
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

  test "cannot post message after messaging deadline and form reflects expiry" do
    @booking.update_columns(status: Booking.statuses[:accepted])
    @ride.update_columns(departure_time: 25.hours.ago, expected_arrival_at: 24.hours.ago)
    sign_in_as(@passenger)

    assert_no_difference "ChatMessage.count" do
      post ride_post_chat_messages_url(@ride), params: {
        chat_message: { body: "Late message" }
      }, as: :turbo_stream
    end

    assert_response :unprocessable_content
    assert_includes response.body, "Messaging for this trip has closed."
    assert_includes response.body, "Philippine time (UTC+8)"
    assert_includes response.body, "Chat writes are closed 24 hours after the booking cutoff"
  end

  test "cannot post message when chat is expired and redirects with alert" do
    @booking.update_columns(status: Booking.statuses[:accepted])
    @ride.update_columns(departure_time: 35.days.ago, expected_arrival_at: 34.days.ago)
    sign_in_as(@passenger)

    assert_no_difference "ChatMessage.count" do
      post ride_post_chat_messages_url(@ride), params: {
        chat_message: { body: "Expired message" }
      }
    end

    assert_redirected_to ride_post_url(@ride)
    assert_equal "Chat history for this trip is no longer available.", flash[:alert]
  end

  test "confirmed passenger can post message on canceled trip during coordination window" do
    @booking.update_columns(status: Booking.statuses[:accepted])
    RidePosts::CancelService.call(@ride, actor: @driver)
    sign_in_as(@passenger)

    assert_difference -> { @ride.chat_messages.count } => 1 do
      post ride_post_chat_messages_url(@ride), params: {
        chat_message: { body: "Can we still share a taxi?" }
      }
    end

    assert_redirected_to ride_post_url(@ride, tab: "chat")
    assert_equal "Can we still share a taxi?", @ride.chat_messages.last.body
  end

  test "cannot post message 24 hours after cancellation" do
    @booking.update_columns(status: Booking.statuses[:accepted])
    RidePosts::CancelService.call(@ride, actor: @driver)
    @ride.update_columns(canceled_at: 25.hours.ago)
    sign_in_as(@passenger)

    assert_no_difference "ChatMessage.count" do
      post ride_post_chat_messages_url(@ride), params: {
        chat_message: { body: "Too late" }
      }, as: :turbo_stream
    end

    assert_response :unprocessable_content
    assert_includes response.body, "Trip canceled &amp; messaging has closed."
    assert_includes response.body, "Chat writes are closed 24 hours after trip cancellation"
  end
end
