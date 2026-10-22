# frozen_string_literal: true

require "test_helper"

class ChatReadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @ride = ride_posts(:one)
    @driver = @ride.user
    @passenger = users(:two)
    bookings(:one).update_columns(status: Booking.statuses[:accepted], accepted_at: 1.day.ago)
    @message = @ride.chat_messages.create!(user: @driver, body: "Pickup at 8:00 AM")
  end

  test "foreign and nonexistent message markers cannot suppress unread conversations" do
    other = ride_posts(:two)
    Booking.create!(ride_post: other, passenger: @driver, status: :accepted)
    foreign = other.chat_messages.create!(user: @passenger, body: "Other trip")
    sign_in_as(@passenger)
    [ foreign.id, @message.id + 1_000_000, "#{@message.id}abc" ].each do |id|
      post ride_post_chat_reads_path(@ride), params: { last_message_id: id }
      assert_response :unprocessable_content
      assert_equal 1, @passenger.unread_chats_count
      assert_nil @passenger.chat_read_states.find_by(ride_post: @ride)
    end
  end

  test "authorized participant marks conversation read" do
    sign_in_as(@passenger)
    assert_equal 1, @passenger.unread_chats_count

    post ride_post_chat_reads_path(@ride), params: { last_message_id: @message.id }

    assert_response :success
    assert_equal 0, @passenger.unread_chats_count
    read_state = @passenger.chat_read_states.find_by(ride_post: @ride)
    assert_equal @message.id, read_state.last_read_message_id
  end

  test "unauthenticated user is redirected to sign in" do
    post ride_post_chat_reads_path(@ride), params: { last_message_id: @message.id }
    assert_redirected_to new_session_path
  end

  test "unauthorized user cannot mark conversation read" do
    other_user = users(:one)
    # Give other_user a separate identity not participating in @ride
    bookings(:one).update_columns(passenger_id: @passenger.id)
    # Sign in as nonparticipant
    stranger = User.create!(
      email_address: "stranger@example.com",
      password: "password",
      first_name: "Stranger",
      last_name: "User"
    )
    sign_in_as(stranger)

    post ride_post_chat_reads_path(@ride), params: { last_message_id: @message.id }
    assert_response :forbidden
    assert_nil stranger.chat_read_states.find_by(ride_post: @ride)
  end

  test "marking with older message ID does not overwrite newer read state" do
    msg2 = @ride.chat_messages.create!(user: @driver, body: "Second message")
    sign_in_as(@passenger)

    post ride_post_chat_reads_path(@ride), params: { last_message_id: msg2.id }
    assert_response :success
    read_state = @passenger.chat_read_states.find_by(ride_post: @ride)
    assert_equal msg2.id, read_state.last_read_message_id

    # Older update arrives
    post ride_post_chat_reads_path(@ride), params: { last_message_id: @message.id }
    assert_response :success
    read_state.reload
    assert_equal msg2.id, read_state.last_read_message_id
  end
end
