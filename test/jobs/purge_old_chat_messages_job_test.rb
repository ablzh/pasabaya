# frozen_string_literal: true

require "test_helper"

class PurgeOldChatMessagesJobTest < ActiveJob::TestCase
  setup do
    @ride = ride_posts(:one)
    @driver = @ride.user
    @booking = bookings(:one)
    @booking.update_columns(status: Booking.statuses[:accepted])
  end

  test "purges messages from expired conversations and keeps retained conversations" do
    expired_old_msg = @ride.chat_messages.create!(user: @driver, body: "Message from last month")
    expired_recent_msg = @ride.chat_messages.create!(user: @driver, body: "Message from today")
    @ride.update_columns(departure_time: 35.days.ago, expected_arrival_at: 34.days.ago)

    retained_ride = ride_posts(:two)
    Booking.create!(ride_post: retained_ride, passenger: users(:one), status: :accepted)
    retained_msg = retained_ride.chat_messages.create!(user: retained_ride.user, body: "Retained message")
    retained_ride.update_columns(departure_time: 2.days.ago, expected_arrival_at: 1.day.ago)

    assert_difference("ChatMessage.count", -2) do
      PurgeOldChatMessagesJob.perform_now
    end

    assert_not ChatMessage.exists?(expired_old_msg.id)
    assert_not ChatMessage.exists?(expired_recent_msg.id)
    assert ChatMessage.exists?(retained_msg.id)
  end
end
