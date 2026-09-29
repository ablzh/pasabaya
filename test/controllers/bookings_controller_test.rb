require "test_helper"

class BookingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @ride = ride_posts(:one)
    @driver = @ride.user
    @passenger = users(:two)
  end

  test "passenger can request a seat on a bookable ride" do
    # Remove existing fixture booking so user :two has no active booking
    bookings(:one).destroy!

    sign_in_as(@passenger)

    assert_difference -> { @ride.bookings.count } => 1, -> { Notification.count } => 1 do
      post ride_post_bookings_url(@ride), params: {
        booking: { pickup_notes: "Can meet near Buendia MRT" }
      }
    end

    assert_redirected_to ride_post_url(@ride)
    booking = @ride.bookings.last
    assert_equal @passenger, booking.passenger
    assert_equal "Can meet near Buendia MRT", booking.pickup_notes
    assert booking.pending?
  end

  test "driver can accept a pending booking" do
    booking = bookings(:one)
    sign_in_as(@driver)

    patch accept_booking_url(booking)

    assert_redirected_to ride_post_url(@ride)
    assert booking.reload.accepted?
  end

  test "driver can decline a pending booking" do
    booking = bookings(:one)
    sign_in_as(@driver)

    patch decline_booking_url(booking)

    assert_redirected_to ride_post_url(@ride)
    assert booking.reload.declined?
  end

  test "passenger can cancel their pending booking" do
    booking = bookings(:one)
    sign_in_as(@passenger)

    patch cancel_booking_url(booking)

    assert_redirected_to ride_post_url(@ride)
    assert booking.reload.canceled?
  end

  test "unauthenticated user cannot create booking" do
    post ride_post_bookings_url(@ride), params: {
      booking: { pickup_notes: "Meetup" }
    }

    assert_redirected_to new_session_url
  end
end
