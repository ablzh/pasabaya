# frozen_string_literal: true

require "test_helper"

class RidePostChatRetentionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @ride = ride_posts(:one)
    @driver = @ride.user
    @passenger = users(:two)
    @booking = bookings(:one)
    @booking.update_columns(status: Booking.statuses[:accepted])
  end

  test "chat deadlines are computed from booking cutoff" do
    cutoff = @ride.booking_cutoff_at
    assert_not_nil cutoff

    assert_equal cutoff + 24.hours, @ride.chat_messaging_closes_at
    assert_equal cutoff + 24.hours + 30.days, @ride.chat_history_unavailable_at
  end

  test "chat messaging closes 24 hours after booking cutoff regardless of earlier automatic completion" do
    # Trip completed 2 hours ago, but departure was 5 hours ago (booking cutoff 5 hours ago)
    # 24h has NOT elapsed yet
    @ride.update_columns(
      departure_time: 5.hours.ago,
      expected_arrival_at: 4.hours.ago,
      status: RidePost.statuses[:completed]
    )

    assert @ride.completed?
    assert @ride.chat_messaging_closes_at > Time.current
    assert @ride.chat_writable?, "Chat must remain writable before messaging closes, regardless of completion"

    # Now move past 24 hours after departure
    @ride.update_columns(
      departure_time: 25.hours.ago,
      expected_arrival_at: 24.hours.ago
    )

    assert_not @ride.chat_writable?, "Chat must not be writable after messaging deadline"
    assert @ride.chat_readable?, "Chat must remain readable during the 30-day retention window"
    assert_not @ride.chat_expired?
  end

  test "chat becomes expired and unavailable after history deadline" do
    # History deadline is cutoff + 24 hours + 30 days = cutoff + 31 days
    @ride.update_columns(
      departure_time: 32.days.ago,
      expected_arrival_at: 31.days.ago,
      status: RidePost.statuses[:completed]
    )

    assert @ride.chat_expired?
    assert_not @ride.chat_writable?
    assert_not @ride.chat_readable?
    assert_not @ride.user_authorized_for_chat?(@driver)
    assert_not @ride.user_authorized_for_chat?(@passenger)
  end

  test "updating ride departure schedules ChatRetentionJob" do
    ride = ride_posts(:two)
    ride.bookings.delete_all
    new_time = 5.days.from_now
    assert_enqueued_with(job: ChatRetentionJob, at: new_time + 24.hours + 30.days) do
      ride.update!(departure_time: new_time, expected_arrival_at: new_time + 2.hours)
    end
  end
end
