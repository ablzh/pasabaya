require "application_system_test_case"

class CloseRideRequestsSystemTest < ApplicationSystemTestCase
  test "driver closes further requests and continues coordinating the confirmed trip" do
    ride = ride_posts(:one)
    booking = bookings(:one)
    Bookings::AcceptService.call(booking, actor: ride.user)

    sign_in(ride.user)
    visit ride_post_path(ride)

    dismiss_confirm do
      click_button "Close seat requests"
    end
    assert_button "Close seat requests"
    assert_nil ride.reload.requests_closed_at

    accept_confirm do
      click_button "Close seat requests"
    end
    assert_no_button "Close seat requests"
    assert_button "Reopen seat requests"
    assert_button "Cancel Trip"

    click_button "Reopen seat requests"
    assert_button "Close seat requests"
    assert_no_button "Reopen seat requests"
    assert ride.reload.bookable?

    accept_confirm do
      click_button "Close seat requests"
    end
    assert_button "Reopen seat requests"

    find("#trip-chat-tab").click
    fill_in "Coordination message", with: "Our confirmed trip is still on"
    click_button "Send"
    assert_selector ".chat-message", text: "Our confirmed trip is still on", count: 1
    assert booking.reload.accepted?
    assert ride.reload.active?
    assert_not ride.bookable?
  end
end
