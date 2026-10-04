require "application_system_test_case"

class ChatDeadlineTransitionsTest < ApplicationSystemTestCase
  setup do
    @ride = ride_posts(:one)
    bookings(:one).update_columns(status: Booking.statuses[:accepted], accepted_at: 1.hour.ago)
    @ride.chat_messages.create!(user: users(:one), body: "Retained private discussion")
    visit new_session_path
    fill_in "Email Address", with: users(:two).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_current_path root_path
  end

  test "already open discussion switches to read only when messaging ends" do
    @ride.update_columns(departure_time: 24.hours.ago + 8.seconds, expected_arrival_at: nil)
    visit ride_post_path(@ride, tab: "chat")
    assert_selector "#chat_message_form input"
    assert_no_selector "#chat_message_form input", wait: 12
    assert_text "Messaging for this trip has closed."
    assert_text "Retained private discussion"
  end

  test "already open history disappears at retention deadline" do
    @ride.update_columns(departure_time: 31.days.ago + 8.seconds, expected_arrival_at: nil)
    visit ride_post_path(@ride, tab: "chat")
    assert_text "Retained private discussion"
    assert_no_text "Retained private discussion", wait: 12
    assert_text "Chat history for this trip is no longer available."
    assert_no_selector "#chat_message_form input"
  end

  test "canceled discussion updates its coordination notice when messaging ends" do
    @ride.update_columns(status: RidePost.statuses[:canceled], canceled_at: 24.hours.ago + 8.seconds)
    visit ride_post_path(@ride, tab: "chat")
    assert_text "Coordination messaging remains open for 24 hours following cancellation."
    assert_no_selector "#chat_message_form input", wait: 12
    assert_text "Trip canceled. Messaging is closed."
    assert_no_text "Coordination messaging remains open"
    assert_text "Retained private discussion"
  end

  test "open chat receives revised cancellation state and deadlines" do
    visit ride_post_path(@ride, tab: "chat")
    assert_selector "#chat_message_form input"
    RidePosts::CancelService.call(@ride, actor: users(:one))
    assert_text "Coordination messaging remains open for 24 hours following cancellation."
    assert_selector ".chat-deadlines time[datetime='#{@ride.reload.chat_messaging_closes_at.iso8601}']"
    assert_selector "#chat_message_form input"
  end
end
