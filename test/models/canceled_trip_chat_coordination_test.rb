# frozen_string_literal: true

require "test_helper"

class CanceledTripChatCoordinationTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @ride = ride_posts(:one)
    @driver = @ride.user
    @passenger = users(:two)
    @booking = bookings(:one)
    @booking.update_columns(status: Booking.statuses[:accepted], accepted_at: 1.hour.ago)
  end

  test "canceling a trip with an open chat preserves access for driver and previously accepted passengers" do
    assert @ride.chat_unlocked?

    RidePosts::CancelService.call(@ride, actor: @driver)
    @ride.reload

    assert @ride.canceled?
    assert @ride.canceled_at.present?
    assert @ride.chat_unlocked?
    assert @ride.user_authorized_for_chat?(@driver)
    assert @ride.user_authorized_for_chat?(@passenger)
    assert_includes @ride.participants, @driver
    assert_includes @ride.participants, @passenger
  end

  test "messaging remains available for 24 hours after cancellation followed by 30 days read-only" do
    RidePosts::CancelService.call(@ride, actor: @driver)
    @ride.reload

    assert @ride.chat_writable?, "Chat must remain writable immediately after cancellation"
    assert_equal @ride.canceled_at + 24.hours, @ride.chat_messaging_closes_at
    assert_equal @ride.canceled_at + 24.hours + 30.days, @ride.chat_history_unavailable_at

    # Move past 24 hours after cancellation
    @ride.update_columns(canceled_at: 25.hours.ago)

    assert_not @ride.chat_writable?, "Chat writes must close 24 hours after cancellation"
    assert @ride.chat_readable?, "Chat must remain readable during the 30-day history window"
    assert_not @ride.chat_expired?

    # Move past history deadline
    @ride.update_columns(canceled_at: 32.days.ago)

    assert @ride.chat_expired?
    assert_not @ride.chat_readable?
    assert_not @ride.user_authorized_for_chat?(@driver)
    assert_not @ride.user_authorized_for_chat?(@passenger)
  end

  test "cancellation never reopens chat whose messaging window is already closed" do
    # Trip departed 26 hours ago -> messaging window closed 2 hours ago
    @ride.update_columns(departure_time: 26.hours.ago, expected_arrival_at: 25.hours.ago)
    assert_not @ride.chat_writable?

    RidePosts::CancelService.call(@ride, actor: @driver)
    @ride.reload

    assert_not @ride.chat_writable?, "Cancellation must never reopen a closed messaging window"
    assert @ride.chat_readable?, "History remains readable"
  end

  test "cancellation never restores history that has become unavailable" do
    # Trip departed 35 days ago -> history expired 4 days ago
    @ride.update_columns(departure_time: 35.days.ago, expected_arrival_at: 34.days.ago)
    assert @ride.chat_expired?

    # Even if canceled now, history must stay expired
    @ride.update_columns(status: RidePost.statuses[:canceled], canceled_at: Time.current)

    assert @ride.chat_expired?, "History must not be restored"
    assert_not @ride.user_authorized_for_chat?(@driver)
    assert_not @ride.user_authorized_for_chat?(@passenger)
  end

  test "pending declined and individually canceled passengers cannot access canceled trip chat" do
    # Pending booking
    pending_user = User.create!(email_address: "pending@example.com", password: "password123", first_name: "Pen", last_name: "Ding")
    Booking.create!(ride_post: @ride, passenger: pending_user, status: :pending)

    # Declined booking
    declined_user = User.create!(email_address: "declined@example.com", password: "password123", first_name: "Dec", last_name: "Lined")
    Booking.create!(ride_post: @ride, passenger: declined_user, status: :declined)

    # Individually canceled passenger before trip cancellation
    indiv_canceled_user = User.create!(email_address: "indiv@example.com", password: "password123", first_name: "Indiv", last_name: "Cancel")
    b = Booking.create!(ride_post: @ride, passenger: indiv_canceled_user, status: :accepted, accepted_at: 2.hours.ago)
    travel_to 1.hour.ago do
      Bookings::CancelService.call(b, actor: indiv_canceled_user)
    end

    RidePosts::CancelService.call(@ride, actor: @driver)
    @ride.reload

    assert_not @ride.user_authorized_for_chat?(pending_user)
    assert_not @ride.user_authorized_for_chat?(declined_user)
    assert_not @ride.user_authorized_for_chat?(indiv_canceled_user)
    assert @ride.user_authorized_for_chat?(@passenger)
  end

  test "bans and loss of required hub access revoke chat access immediately" do
    RidePosts::CancelService.call(@ride, actor: @driver)
    @ride.reload

    assert @ride.user_authorized_for_chat?(@passenger)

    # Banned passenger
    @passenger.update_columns(banned_at: Time.current)
    assert_not @ride.user_authorized_for_chat?(@passenger)

    # Hub-only ride with revoked membership
    @passenger.update_columns(banned_at: nil)
    @ride.update_columns(visibility: RidePost.visibilities[:hub_only], community_id: communities(:two).id)
    membership = community_memberships(:two)
    membership.update_columns(verified_at: 1.day.ago, revoked_at: nil)
    assert @ride.user_authorized_for_chat?(@passenger)

    membership.update_columns(revoked_at: Time.current)
    assert_not @ride.user_authorized_for_chat?(@passenger)
  end

  test "repeated cancellation processing does not extend deadlines or duplicate retention jobs" do
    RidePosts::CancelService.call(@ride, actor: @driver)
    @ride.reload
    original_canceled_at = @ride.canceled_at
    original_messaging_close = @ride.chat_messaging_closes_at

    travel 2.hours do
      assert_no_enqueued_jobs(only: ChatRetentionJob) do
        RidePosts::CancelService.call(@ride, actor: @driver)
      end
      @ride.reload
      assert_equal original_canceled_at, @ride.canceled_at
      assert_equal original_messaging_close, @ride.chat_messaging_closes_at
    end
  end
end
