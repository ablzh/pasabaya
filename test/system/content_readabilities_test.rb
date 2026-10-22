require "application_system_test_case"

class ContentReadabilitiesTest < ApplicationSystemTestCase
  test "incoming and own messages wrap within the conversation without template whitespace" do
    ride = ride_posts(:one)
    bookings(:one).update_columns(status: Booking.statuses[:accepted], accepted_at: Time.current)
    users(:two).update!(first_name: "LongName" * 16)
    bodies = [ [ users(:two), "A" * 1000 ], [ users(:one), "https://example.test/" + "path" * 200 ], [ users(:two), "Hello!" ], [ users(:one), "First line\nSecond line 👩🏽‍💻 <b>literal</b>" ] ]
    messages = Prosopite.pause { bodies.map { |user, body| ride.chat_messages.create!(user: user, body: body) } }
    sign_in(users(:one))

    [ [ 320, "light" ], [ 1440, "dark" ] ].each do |width, theme|
      resize_and_visit(width, ride_post_path(ride, tab: "chat"), theme)
      assert_selector ".chat-message[data-own-message='true']"
      messages.each do |message|
        bubble = find("#chat_message_#{message.id} .chat-message-body")
        assert_equal message.body, bubble.evaluate_script("this.textContent")
        assert_contained("#chat_message_#{message.id} .chat-message-body", "#chat_messages_list")
        assert_contained("#chat_message_#{message.id} .chat-message-content", "#chat_messages_list")
      end
      assert_contained(".chat-message-author", "#chat_messages_list")
      assert_text_contrast(".chat-message-content > span", 4.5)
    end
  end

  test "newly delivered long messages remain wrapped" do
    ride = ride_posts(:one)
    bookings(:one).update_columns(status: Booking.statuses[:accepted], accepted_at: Time.current)
    sign_in(users(:one))
    resize_and_visit(320, ride_post_path(ride, tab: "chat"))
    assert_selector "turbo-cable-stream-source[connected]", visible: :all
    message = ride.chat_messages.create!(user: users(:two), body: "LiveToken" * 110)
    assert_selector "#chat_message_#{message.id}"
    assert_contained("#chat_message_#{message.id} .chat-message-body", "#chat_messages_list")
  end

  test "long profile identity Hub labels and ride cards stay readable" do
    users(:one).update!(first_name: "QA Driver With A Long Display Name", last_name: "Audit")
    communities(:one).update!(name: "LongCommunityName" * 8)
    ride_posts(:one).update!(visibility: :hub_only, community: communities(:one))
    sign_in(users(:one))
    [ 320, 1440 ].each do |width|
      resize_and_visit(width, user_path(users(:one)))
      assert_contained("[data-profile-name]", "[data-profile-name]", text: true)
      assert_contained("[data-profile-name]", "[data-profile-name]", parent: true)
      assert_document_contained
      assert_text communities(:one).name
      assert_contained("#ride_post_#{ride_posts(:one).id} p", "#ride_post_#{ride_posts(:one).id}")
    end
  end

  test "trip and pending or accepted pickup notes wrap without widening their cards" do
    ride = ride_posts(:one)
    ride.update!(notes: "UnbrokenTripNote" * 18)
    bookings(:one).update!(pickup_notes: "UnbrokenPickupNote" * 12)
    sign_in(users(:one))
    [ :pending, :accepted ].each do |status|
      bookings(:one).update_columns(status: Booking.statuses[status], accepted_at: status == :accepted ? Time.current : nil)
      [ 320, 1440 ].each do |width|
        resize_and_visit(width, ride_post_path(ride))
        assert_document_contained
        assert_contained("#trip-details-pane p", "#trip-details-pane")
        assert_contained(".whitespace-pre-wrap", "#trip-details-pane")
        assert_button(status == :pending ? "Accept" : "Cancel Seat")
      end
    end
  end

  test "Hub list and all membership states wrap long names domains and mailboxes" do
    hub = communities(:one)
    hub.update!(name: "LongCommunityName" * 8, domain: "long-domain-" + "a" * 40 + ".example.test")
    membership = community_memberships(:one)
    membership.update_columns(institutional_email: "longmailbox" * 10 + "@" + hub.domain)
    sign_in(users(:one))
    [ :verified, :pending, :none ].each do |state|
      membership.update_columns(verified_at: state == :verified ? Time.current : nil, revoked_at: state == :none ? Time.current : nil)
      [ 320, 1440 ].each do |width|
        resize_and_visit(width, community_path(hub))
        assert_document_contained
        assert_contained("main h1", "main")
        assert_contained("main p", "main")
      end
    end
    resize_and_visit(320, communities_path)
    assert_document_contained
    assert_contained("main h2", "main")
  end

  test "notification cards keep long event text and actions visible" do
    users(:two).update!(first_name: "LongActorName" * 16)
    sign_in(users(:one))
    [ 320, 1440 ].each do |width|
      resize_and_visit(width, notifications_path)
      assert_selector ".notification a[href='#{notification_path(notifications(:one))}']"
      assert_contained(".notification p", ".notification")
      header_clear = page.evaluate_script("(() => {const h=document.querySelector('main h1').getBoundingClientRect(), b=document.querySelector('form[action=\"#{mark_all_as_read_notifications_path}\"] button').getBoundingClientRect();return b.left >= h.right || b.top >= h.bottom;})()")
      assert header_clear, "Mark all read must not overlap the heading"
      assert_document_contained
    end
  end

  test "passenger booking actions remain contained on phone and desktop" do
    sign_in(users(:two))
    [ :pending, :accepted ].each do |status|
      bookings(:one).update_columns(status: Booking.statuses[status], accepted_at: status == :accepted ? 1.hour.ago : nil)
      [ 320, 1440 ].each do |width|
        page.driver.resize(width, 900)
        visit ride_post_path(ride_posts(:one))
        within ".passenger-booking-content" do
          assert_button(status == :pending ? "Cancel Request" : "Cancel Booking")
        end
        bounds = page.evaluate_script <<~JS
          (() => {
            const content = document.querySelector('.passenger-booking-content');
            const rect = el => el.getBoundingClientRect().toJSON();
            return {content: rect(content), children: [...content.children].map(rect), overflow: document.documentElement.scrollWidth > innerWidth};
          })()
        JS
        bounds["children"].each do |child|
          assert_operator child["left"], :>=, bounds["content"]["left"] - 1
          assert_operator child["right"], :<=, bounds["content"]["right"] + 1
        end
        assert_not bounds["overflow"]
      end
    end
  end
end
