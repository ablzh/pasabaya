require "application_system_test_case"

class TripChatTest < ApplicationSystemTestCase
  test "request accept and chat flow renders streamed messages for each viewer on a phone" do
    ride = ride_posts(:one)
    bookings(:one).destroy!
    page.current_window.resize_to(390, 844)

    using_session(:driver) do
      sign_in(users(:one))
    end
    sign_in(users(:two))
    visit ride_post_path(ride)
    click_button "Request Seat"
    assert_text "Seat Requested"

    using_session(:driver) do
      visit ride_post_path(ride)
      click_button "Accept"
      assert_text "Booking accepted!"
      find("#trip-details-tab").send_keys(:right)
      assert_selector '#trip-chat-tab[aria-selected="true"][tabindex="0"]'
      assert_selector "turbo-cable-stream-source[connected]", visible: :all
    end

    visit ride_post_path(ride, tab: "chat")
    assert_selector "turbo-cable-stream-source[connected]", visible: :all, count: 2
    assert_text "No messages yet."
    assert page.evaluate_script("document.querySelector('#chat_message_form').getBoundingClientRect().bottom <= window.innerHeight"), "The phone composer must fit below the page header"

    using_session(:driver) do
      fill_in "Coordination message", with: "Meet at the station"
      click_button "Send"
      assert_selector '.chat-message[data-own-message="true"]', text: "Meet at the station"
      assert_no_text "No messages yet."
    end

    assert_selector '.chat-message[data-own-message="false"]', text: "Meet at the station"
    assert_selector ".chat-message-author", text: "Juan"
    assert_no_text "No messages yet."
    fill_in "Coordination message", with: "I will be there"
    click_button "Send"
    assert_selector '.chat-message[data-own-message="true"]', text: "I will be there"
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "Phone chat must not overflow horizontally"

    using_session(:driver) do
      assert_selector '.chat-message[data-own-message="false"]', text: "I will be there"
    end
  end

  private

  def sign_in(user)
    visit new_session_path
    fill_in "Email Address", with: user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_current_path root_path
  end
end
