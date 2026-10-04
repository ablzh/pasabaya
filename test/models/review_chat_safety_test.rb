require "test_helper"

class ReviewChatSafetyTest < ActiveSupport::TestCase
  setup do
    @ride = ride_posts(:one)
    @driver = users(:one)
    @passenger = users(:two)
    bookings(:one).update_columns(status: Booking.statuses[:accepted], accepted_at: 1.hour.ago)
  end

  test "late open cancellation grants 24 hours of coordination" do
    @ride.update_columns(departure_time: 23.hours.ago, expected_arrival_at: nil)
    RidePosts::CancelService.call(@ride, actor: @driver)
    assert_equal @ride.reload.canceled_at + 24.hours, @ride.chat_messaging_closes_at
  end

  test "send and history access end exactly at their deadlines and scheduled purge removes reading state" do
    message = @ride.chat_messages.create!(user: @driver, body: "Private history")
    travel_to @ride.chat_messaging_closes_at do
      assert_not @ride.chat_writable?
      assert @ride.chat_readable?
    end
    travel_to @ride.chat_history_unavailable_at do
      assert @ride.chat_expired?
      assert_not @ride.user_authorized_for_chat?(@driver)
      ChatRetentionJob.perform_now(@ride.id)
      assert_not ChatMessage.exists?(message.id)
      assert_empty @ride.chat_read_states.reload
    end
  end

  test "driver loses hub chat access immediately after membership revocation" do
    @ride.update_columns(visibility: RidePost.visibilities[:hub_only], community_id: communities(:one).id)
    assert @ride.user_authorized_for_chat?(@driver)
    community_memberships(:one).update_columns(revoked_at: Time.current)
    assert_not @ride.user_authorized_for_chat?(@driver)
  end
end
