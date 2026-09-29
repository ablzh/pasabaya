# frozen_string_literal: true

require "test_helper"

class PurgeOldChatMessagesJobTest < ActiveJob::TestCase
  setup do
    @ride = ride_posts(:one)
    @driver = @ride.user
    @booking = bookings(:one)
    @booking.update_columns(status: Booking.statuses[:accepted])
  end

  test "purges messages older than 30 days" do
    old_msg = @ride.chat_messages.create!(user: @driver, body: "Message from last month")
    old_msg.update_columns(created_at: 35.days.ago)

    recent_msg = @ride.chat_messages.create!(user: @driver, body: "Message from today")

    assert_difference("ChatMessage.count", -1) do
      PurgeOldChatMessagesJob.perform_now(30)
    end

    assert_not ChatMessage.exists?(old_msg.id)
    assert ChatMessage.exists?(recent_msg.id)
  end
end
