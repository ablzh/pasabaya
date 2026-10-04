require "application_system_test_case"

class MobileTripChatTest < ApplicationSystemTestCase
  setup do
    @ride = ride_posts(:one)
    bookings(:one).update_columns(status: Booking.statuses[:accepted], accepted_at: 1.hour.ago)
    page.driver.resize(390, 844)
    visit new_session_path
    fill_in "Email Address", with: users(:two).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_current_path root_path
  end

  test "mobile discussion fills viewport and restores trip and desktop navigation" do
    visit ride_post_path(@ride, tab: "chat")
    assert_selector "#chat_message_form input"
    assert_no_selector ".web-navigation"
    assert_no_selector ".web-footer"
    assert_no_selector "#trip-details-tab"
    assert_chat_fits(844)
    within ".trip-chat" do
      assert_text "Manila"
      assert_text "Makati"
      assert_text "Driver: Juan Dela Cruz"
      find("button[aria-label='Back to trip']").click
    end
    assert_selector "#trip-details-pane:not(.hidden)"
    assert_selector ".web-navigation"
    click_button "Live Chat"
    page.driver.resize(1440, 900)
    assert_selector ".web-navigation"
    assert_selector ".web-footer"
    assert_selector "#chat_message_form input"
    assert_operator page.evaluate_script("document.querySelector('.trip-chat').getBoundingClientRect().height"), :<, 900
  end

  test "composer follows a reduced visual viewport and landscape height" do
    visit ride_post_path(@ride, tab: "chat")
    assert_selector "#chat_message_form input"
    page.execute_script("Object.defineProperties(window.visualViewport, {height: {value: 420, configurable: true}, offsetTop: {value: 30, configurable: true}}); window.visualViewport.dispatchEvent(new Event('resize'))")
    assert_chat_fits(420, top: 30)
    fill_in "Coordination message", with: "Composer stays reachable"
    page.execute_script("delete window.visualViewport.height; delete window.visualViewport.offsetTop")
    page.driver.resize(740, 390)
    page.execute_script("window.visualViewport.dispatchEvent(new Event('resize'))")
    assert_chat_fits(390)
    assert_text "Messaging closes:"
    assert_text "Scheduled live-database deletion:"
    assert_operator page.evaluate_script("document.querySelector('#chat_messages_list').clientHeight"), :>, 50
    assert_operator page.evaluate_script("parseFloat(getComputedStyle(document.querySelector('#chat_message_form')).paddingBottom)"), :>=, 12
  end

  test "chat follows incoming messages at bottom and preserves older history through resize" do
    Prosopite.pause do
      20.times { |index| @ride.chat_messages.create!(user: @ride.user, body: "Earlier message #{index}. " * 4) }
    end
    visit ride_post_path(@ride, tab: "chat")
    assert_selector "turbo-cable-stream-source[connected]", visible: :all, count: 2
    assert_at_bottom
    @ride.chat_messages.create!(user: @ride.user, body: "Long incoming message. " * 35)
    assert_selector ".chat-message", text: "Long incoming message."
    assert_at_bottom
    page.execute_script("const list = document.querySelector('#chat_messages_list'); list.scrollTop = 0; list.dispatchEvent(new Event('scroll'))")
    @ride.chat_messages.create!(user: @ride.user, body: "New message while reading history")
    assert_selector ".chat-message", text: "New message while reading history", visible: :all
    assert_in_delta 0, page.evaluate_script("document.querySelector('#chat_messages_list').scrollTop"), 1
    page.driver.resize(740, 390)
    page.execute_script("window.visualViewport.dispatchEvent(new Event('resize'))")
    assert_chat_fits(390)
    assert_in_delta 0, page.evaluate_script("document.querySelector('#chat_messages_list').scrollTop"), 1
    page.execute_script("const list = document.querySelector('#chat_messages_list'); list.scrollTop = list.scrollHeight; list.dispatchEvent(new Event('scroll'))")
    assert_at_bottom
    visit chats_path
    assert_selector "a[data-conversation-unread='false'][href='#{ride_post_path(@ride, tab: 'chat')}']"
  end

  test "read only deadlines stay available and expired history has no active composer" do
    @ride.update_columns(departure_date: 3.days.ago.to_date, departure_time: 3.days.ago)
    visit ride_post_path(@ride, tab: "chat")
    assert_text "Read-only"
    assert_text "Messaging for this trip has closed."
    assert_no_selector "#chat_message_form input"
    assert_selector ".chat-deadlines time", count: 2
    assert_chat_fits(844)
    @ride.update_columns(departure_date: 33.days.ago.to_date, departure_time: 33.days.ago)
    visit ride_post_path(@ride, tab: "chat")
    assert_text "Chat history for this trip is no longer available."
    assert_no_selector "#trip-chat-pane"
    assert_no_selector "#chat_message_form input"
    assert_selector ".web-navigation"
  end

  private

  def assert_at_bottom
    page.document.synchronize(errors: [ Minitest::Assertion ]) do
      assert_operator page.evaluate_script("(() => {const list = document.querySelector('#chat_messages_list'); return list.scrollHeight - list.scrollTop - list.clientHeight})()"), :<=, 1
    end
  end

  def assert_chat_fits(height, top: 0)
    page.document.synchronize(errors: [ Minitest::Assertion ]) do
      bounds = page.evaluate_script("(() => { const r = document.querySelector('.trip-chat').getBoundingClientRect(); return {top: r.top, height: r.height, bottom: document.querySelector('#chat_message_form').getBoundingClientRect().bottom}; })()")
      assert_in_delta top, bounds["top"], 1
      assert_in_delta height, bounds["height"], 1
      assert_operator bounds["bottom"], :<=, top + height + 1
    end
  end
end
