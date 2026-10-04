# frozen_string_literal: true

require "application_system_test_case"

class TripChatUnreadTest < ApplicationSystemTestCase
  setup do
    @ride = ride_posts(:one)
    @driver = @ride.user
    @passenger = users(:two)
    bookings(:one).update_columns(status: Booking.statuses[:accepted], accepted_at: 1.day.ago)
  end

  test "unread badge updates in real time and clears when conversation is viewed in foreground at latest message" do
    using_session(:driver) do
      sign_in(@driver)
    end

    sign_in(@passenger)
    assert_current_path root_path

    # Initially, passenger has no unread chats
    assert_no_selector "[data-chat-unread-count] span"

    # Driver sends a message in coordination chat
    using_session(:driver) do
      visit ride_post_path(@ride, tab: "chat")
      fill_in "Coordination message", with: "Meeting time updated to 8:30 AM"
      click_button "Send"
      assert_selector '.chat-message[data-own-message="true"]', text: "Meeting time updated to 8:30 AM"
    end

    # Passenger sees real-time unread badge update in navbar
    assert_selector "[data-chat-unread-count]", text: "1"

    # Passenger visits inbox: conversation is identified as unread
    visit chats_path
    chat_url = ride_post_path(@ride, tab: "chat")
    assert_selector "a[href='#{chat_url}'][data-conversation-unread='true']" do
      assert_selector "span", text: "Unread"
    end

    # Passenger opens ride page on Details tab: chat is hidden in background tab/pane
    visit ride_post_path(@ride)
    assert_selector "#trip-details-pane:not(.hidden)"
    assert_selector "#trip-chat-pane.hidden", visible: :all
    # Unread badge is still 1 because chat is not in foreground
    assert_selector "[data-chat-unread-count]", text: "1"

    # Passenger switches to Chat tab: chat becomes visible in foreground and reaches latest message
    find("#trip-chat-tab").click
    assert_selector "#trip-chat-pane:not(.hidden)"
    assert_text "Meeting time updated to 8:30 AM"

    # Unread badge clears in real time
    assert_no_selector "[data-chat-unread-count] span"

    # Passenger revisits inbox: conversation is now marked read
    visit chats_path
    assert_selector "a[href='#{chat_url}'][data-conversation-unread='false']"
    assert_no_selector "a[href='#{chat_url}'] span", text: "Unread"
  end

  test "background tab and scrolled above latest message do not clear unread state until reached" do
    # Create several messages so message stream is scrollable
    Prosopite.pause do
      30.times do |i|
        @ride.chat_messages.create!(user: @driver, body: "Message line #{i + 1}")
      end
    end

    sign_in(@passenger)
    assert_selector "[data-chat-unread-count]", text: "1"

    # Set visibility before page scripts run so opening the chat cannot mark it read.
    visibility_script = page.driver.browser.page.command(
      "Page.addScriptToEvaluateOnNewDocument",
      source: "Object.defineProperty(document, 'visibilityState', { value: 'hidden', writable: true, configurable: true });"
    ).fetch("identifier")
    visit ride_post_path(@ride, tab: "chat")

    # Add another message while backgrounded
    @ride.chat_messages.create!(user: @driver, body: "Message while backgrounded")
    assert_selector ".chat-message", text: "Message while backgrounded"
    assert_selector "[data-chat-unread-count]", text: "1"

    # Scrolled above bottom: scroll messages list to top
    page.execute_script("const el = document.querySelector('#chat_messages_list'); if (el) { el.scrollTop = 0; }")

    # Still unread
    assert_equal 1, @passenger.reload.unread_chats_count

    # Now make foreground
    page.execute_script("Object.defineProperty(document, 'visibilityState', { value: 'visible', writable: true, configurable: true }); document.dispatchEvent(new Event('visibilitychange'));")

    # Still scrolled at top: not yet at bottom
    page.execute_script("const el = document.querySelector('#chat_messages_list'); if (el) { el.scrollTop = 0; el.dispatchEvent(new Event('scroll')); }")

    @ride.chat_messages.create!(user: @driver, body: "New pickup while reading earlier history")
    assert_selector ".chat-message", text: "New pickup while reading earlier history", visible: :all
    fill_in "Coordination message", with: "Reply while reading earlier messages"
    click_button "Send"
    assert_selector ".chat-message", text: "Reply while reading earlier messages", visible: :all
    assert_selector "[data-chat-unread-count]", text: "1"
    assert_equal 1, @passenger.reload.unread_chats_count
    assert_operator page.evaluate_script("(() => { const el = document.querySelector('#chat_messages_list'); return el.scrollHeight - el.scrollTop - el.clientHeight; })()"), :>, 50

    # Scroll down to bottom to reach latest message
    page.execute_script("const el = document.querySelector('#chat_messages_list'); if (el) { el.scrollTop = el.scrollHeight; el.dispatchEvent(new Event('scroll')); }")

    # Now conversation becomes read
    assert_no_selector "[data-chat-unread-count] span"
    assert_equal 0, @passenger.reload.unread_chats_count
  ensure
    if visibility_script
      page.driver.browser.page.command("Page.removeScriptToEvaluateOnNewDocument", identifier: visibility_script)
      page.execute_script("delete document.visibilityState; document.dispatchEvent(new Event('visibilitychange'));")
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
