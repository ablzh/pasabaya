# frozen_string_literal: true

require "test_helper"

class ChatRetentionJobTest < ActiveJob::TestCase
  setup do
    @ride = ride_posts(:one)
    @driver = @ride.user
    @booking = bookings(:one)
    @booking.update_columns(status: Booking.statuses[:accepted])
  end

  test "purges messages when ride chat is expired" do
    msg = @ride.chat_messages.create!(user: @driver, body: "Expired chat message")
    @ride.update_columns(departure_time: 35.days.ago, expected_arrival_at: 34.days.ago)

    assert_difference("ChatMessage.count", -1) do
      ChatRetentionJob.perform_now(@ride.id)
    end

    assert_not ChatMessage.exists?(msg.id)
  end

  test "does not purge messages when ride chat is not yet expired" do
    msg = @ride.chat_messages.create!(user: @driver, body: "Retained chat message")
    @ride.update_columns(departure_time: 2.days.ago, expected_arrival_at: 1.day.ago)

    assert_no_difference("ChatMessage.count") do
      ChatRetentionJob.perform_now(@ride.id)
    end

    assert ChatMessage.exists?(msg.id)
  end

  test "is safe to repeat on already purged or nonexistent ride" do
    assert_nothing_raised do
      ChatRetentionJob.perform_now(@ride.id)
      ChatRetentionJob.perform_now(@ride.id)
      ChatRetentionJob.perform_now(-999_999)
    end
  end
end
