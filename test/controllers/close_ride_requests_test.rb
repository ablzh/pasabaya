require "test_helper"

class CloseRideRequestsTest < ActionDispatch::IntegrationTest
  test "driver closes requests without canceling confirmed passengers or their chat" do
    ride = ride_posts(:one)
    confirmed = bookings(:one)
    Bookings::AcceptService.call(confirmed, actor: ride.user)
    waiting_passenger = User.create!(email_address: "waiting@example.com", password: "password", first_name: "Waiting", last_name: "Passenger")
    pending = Booking.create!(ride_post: ride, passenger: waiting_passenger)
    message = ride.chat_messages.create!(user: confirmed.passenger, body: "Our confirmed pickup")
    cutoff = ride.booking_cutoff_at
    chat_deadline = ride.chat_history_unavailable_at
    remaining = ride.reload.remaining_seats
    sign_in_as(ride.user)

    patch "/rides/#{ride.to_param}/close_requests"
    assert_redirected_to ride_post_url(ride)
    assert ride.reload.active?
    assert_not ride.bookable?
    assert_equal remaining, ride.remaining_seats
    assert confirmed.reload.accepted?
    assert pending.reload.expired?
    assert_equal "Your seat request expired without confirmation", waiting_passenger.received_notifications.last.summary
    assert ride.user_authorized_for_chat?(confirmed.passenger)
    assert_equal message, ride.chat_messages.last
    assert_equal cutoff, ride.booking_cutoff_at
    assert_equal chat_deadline, ride.chat_history_unavailable_at

    assert_no_difference "Notification.count" do
      patch "/rides/#{ride.to_param}/close_requests"
    end
    sign_in_as(waiting_passenger)
    assert_no_difference "Booking.count" do
      post ride_post_bookings_url(ride)
    end
    assert_includes flash[:feedback_errors], "This ride is no longer accepting seat requests. Find another ride."
    assert_raises(Bookings::AcceptService::InvalidStateError) do
      Bookings::AcceptService.call(pending, actor: ride.user)
    end
  end

  test "closing requests is restricted to the owner and cannot reopen canceled or completed trips" do
    ride = ride_posts(:one)
    sign_in_as(users(:two))
    patch close_requests_ride_post_url(ride)
    assert_response :not_found
    assert_nil ride.reload.requests_closed_at

    sign_in_as(ride.user)
    %i[canceled completed draft].each do |status|
      ride.update_columns(status: RidePost.statuses[status])
      patch close_requests_ride_post_url(ride)
      assert_redirected_to ride_post_url(ride)
      assert_equal status.to_s, ride.reload.status
      assert_nil ride.requests_closed_at
      assert_match /Only upcoming published trips/, flash[:alert]
    end
  end

  test "closing a full trip preserves confirmed seats and does not reopen when a seat is canceled" do
    ride = ride_posts(:one)
    ride.update!(seats: 1)
    booking = bookings(:one)
    Bookings::AcceptService.call(booking, actor: ride.user)
    sign_in_as(ride.user)

    patch close_requests_ride_post_url(ride)
    assert ride.reload.fulfilled?
    assert_equal 0, ride.remaining_seats
    assert booking.reload.accepted?

    Bookings::CancelService.call(booking, actor: booking.passenger)
    assert_equal 1, ride.reload.remaining_seats
    assert_not ride.bookable?
    patch ride_post_url(ride), params: { intent: "publish", ride_post: { notes: "Same trip" } }
    assert_not ride.reload.bookable?
  end
end
