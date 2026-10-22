require "application_system_test_case"

class PassengerSeatsSystemTest < ApplicationSystemTestCase
  test "driver adjusts passenger seats or types a larger number without submitting" do
    sign_in(users(:one))
    visit new_ride_post_path
    fill_in "Available passenger seats", with: 1
    click_button "Remove one passenger seat"
    assert_field "Available passenger seats", with: "1"
    click_button "Add one passenger seat"
    assert_field "Available passenger seats", with: "2"
    fill_in "Available passenger seats", with: 12
    click_button "Add one passenger seat"
    assert_field "Available passenger seats", with: "13"
    assert_current_path new_ride_post_path
  end

  test "a frozen driver stops new requests while accepted passengers retain coordination" do
    ride = ride_posts(:one)
    booking = bookings(:one)
    driver = users(:one)
    passenger = users(:two)
    Bookings::AcceptService.call(booking, actor: driver)
    remaining_seats = ride.reload.remaining_seats
    driver.update!(booking_freeze_until: 1.day.from_now)
    new_passenger = User.create!(email_address: "new-passenger@example.com", first_name: "New", last_name: "Passenger", password: "password")

    using_session(:new_passenger) do
      sign_in(new_passenger)
      visit ride_post_path(ride)
      assert_no_button "Request Seat"
      assert_no_selector "form[action='#{ride_post_bookings_path(ride)}']"
    end

    sign_in(passenger)
    visit ride_post_path(ride)
    assert_button "Cancel Booking"
    click_button "Open Trip Chat"
    assert_selector "#chat_message_form"
    fill_in "Coordination message", with: "I will meet you at the pickup point"
    click_button "Send"
    assert_selector '.chat-message[data-own-message="true"]', text: "I will meet you at the pickup point"
    assert booking.reload.accepted?
    assert_equal remaining_seats, ride.reload.remaining_seats
  end
end
