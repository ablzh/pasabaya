require "application_system_test_case"

class CloseRideRequestsSystemTest < ApplicationSystemTestCase
  test "driver closes further requests and continues coordinating the confirmed trip" do
    ride = ride_posts(:one)
    booking = bookings(:one)
    Bookings::AcceptService.call(booking, actor: ride.user)

    visit new_session_path
    fill_in "Email Address", with: ride.user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_current_path root_path
    visit ride_post_path(ride)

    click_button "Close seat requests"
    assert_text "Seat requests closed. Confirmed passengers and trip chat are unchanged."
    assert_text "CONFIRMED PASSENGERS (1 / 3)"
    assert_no_button "Close seat requests"
    assert_button "Cancel Trip"

    find("#trip-chat-tab").click
    fill_in "Coordination message", with: "Our confirmed trip is still on"
    click_button "Send"
    assert_text "Our confirmed trip is still on"
    assert booking.reload.accepted?
    assert ride.reload.active?
    assert_not ride.bookable?
  end
end
