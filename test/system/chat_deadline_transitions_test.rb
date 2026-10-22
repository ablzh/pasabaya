require "application_system_test_case"

class ChatDeadlineTransitionsTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup do
    @ride = ride_posts(:one)
    bookings(:one).update_columns(status: Booking.statuses[:accepted], accepted_at: 1.hour.ago)
    @ride.chat_messages.create!(user: users(:one), body: "Retained private discussion")
    sign_in(users(:two))
  end

  test "already open discussion switches to read only when messaging ends" do
    @ride.update_columns(departure_time: 24.hours.ago + 8.seconds)
    visit ride_post_path(@ride, tab: "chat")
    assert_selector "#chat_message_form input"
    assert_no_selector "#chat_message_form input", wait: 12
    assert_selector ".trip-chat[data-chat-scroll-writable-value='false']"
    assert_text "Retained private discussion"
  end

  test "already open history disappears at retention deadline" do
    @ride.update_columns(departure_time: 31.days.ago + 8.seconds)
    visit ride_post_path(@ride, tab: "chat")
    assert_text "Retained private discussion"
    assert_no_text "Retained private discussion", wait: 12
    assert_no_selector "#trip-chat-pane"
    assert_no_selector "#chat_message_form input"
  end

  test "canceled discussion updates its coordination notice when messaging ends" do
    page.driver.resize(320, 420)
    @ride.update_columns(status: RidePost.statuses[:canceled], canceled_at: 24.hours.ago + 8.seconds)
    visit ride_post_path(@ride, tab: "chat")
    notice = find("[data-chat-scroll-target='coordinationNotice']").text
    assert_no_selector ".chat-deadline-policy[open]"
    assert_no_selector "#chat_message_form input", wait: 12
    assert_not_equal notice, find("[data-chat-scroll-target='coordinationNotice']").text
    assert_selector ".trip-chat[data-chat-scroll-writable-value='false']"
    assert_text "Retained private discussion"
  end

  test "open chat receives revised cancellation state and deadlines" do
    visit ride_post_path(@ride, tab: "chat")
    assert_selector "#chat_message_form input"
    perform_enqueued_jobs(only: RideCancellationBroadcastJob) do
      RidePosts::CancelService.call(@ride, actor: users(:one))
    end
    assert_selector "[data-chat-scroll-target='coordinationNotice'][role='status']"
    find(".chat-deadlines summary").click
    assert_selector ".chat-deadlines time[datetime='#{@ride.reload.chat_messaging_closes_at.iso8601}']"
    assert_selector "#chat_message_form input"
  end
end
