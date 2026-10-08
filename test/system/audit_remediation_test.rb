require "application_system_test_case"

class AuditRemediationTest < ApplicationSystemTestCase
  test "incoming and own messages wrap within the conversation without template whitespace" do
    ride = ride_posts(:one)
    bookings(:one).update_columns(status: Booking.statuses[:accepted], accepted_at: Time.current)
    users(:two).update!(first_name: "LongName" * 16)
    bodies = [ [ users(:two), "A" * 1000 ], [ users(:one), "https://example.test/" + "path" * 200 ], [ users(:two), "Hello!" ], [ users(:one), "First line\nSecond line 👩🏽‍💻 <b>literal</b>" ] ]
    messages = Prosopite.pause { bodies.map { |user, body| ride.chat_messages.create!(user: user, body: body) } }
    sign_in(users(:one))

    [ 320, 390, 1440 ].product(%w[light dark]).each do |width, theme|
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
    [ 320, 390, 1440 ].each do |width|
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
      [ 320, 390, 1440 ].each do |width|
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

  test "notification cards contain long event text and have one link without View" do
    users(:two).update!(first_name: "LongActorName" * 16)
    sign_in(users(:one))
    [ 320, 390, 1440 ].product(%w[light dark]).each do |width, theme|
      resize_and_visit(width, notifications_path, theme)
      within ".notification" do
        assert_no_selector "a", text: "View", exact_text: true
        assert_selector "a", count: 1
        assert_text "requested a seat on your ride."
      end
      assert_contained(".notification p", ".notification")
      header_clear = page.evaluate_script("(() => {const h=document.querySelector('main h1').getBoundingClientRect(), b=[...document.querySelectorAll('main button')].find(el=>el.textContent.includes('Mark all')).getBoundingClientRect();return b.left >= h.right || b.top >= h.bottom;})()")
      assert header_clear, "Mark all read must not overlap the heading"
      assert_document_contained
    end
  end

  test "mobile schedule text and settings actions fit with a scrollbar gutter" do
    sign_in(users(:one))
    [ new_ride_post_path, edit_ride_post_path(ride_posts(:one)), settings_profile_path ].each do |path|
      resize_and_visit(320, path)
      page.execute_script("const style = document.createElement('style'); style.textContent = 'html {overflow-y:scroll;scrollbar-gutter:stable} ::-webkit-scrollbar {width:15px}'; document.head.append(style)")
      assert_document_contained
      if path == settings_profile_path
        assert_contained("form button[type='submit']", "form", parent: true)
      else
        assert_contained("[data-controller='departure-choice'] label span", "[data-controller='departure-choice'] label", parent: true)
      end
    end
  end

  test "mobile navigation and chat actions have at least 44px targets" do
    bookings(:one).update_columns(status: Booking.statuses[:accepted], accepted_at: Time.current)
    ride_posts(:one).chat_messages.create!(user: users(:two), body: "Unread coordination message")
    sign_in(users(:one))
    resize_and_visit(320, root_path)
    page.execute_script("const style = document.createElement('style'); style.textContent = 'html {overflow-y:scroll;scrollbar-gutter:stable} ::-webkit-scrollbar {width:15px}'; document.head.append(style)")
    assert_selector ".unread-chats-badge", text: "1"
    assert_document_contained
    targets = page.evaluate_script("[...document.querySelectorAll('.web-navigation [data-navbar-target=menu] > li > a, .web-navigation [data-navbar-target=menu] > li > button')].filter(el => el.getClientRects().length).map(el => ({text:el.textContent, width:el.getBoundingClientRect().width,height:el.getBoundingClientRect().height}))")
    targets.each do |target|
      %w[width height].each { |dimension| assert_operator target[dimension], :>=, 44, target["text"] }
    end
    resize_and_visit(390, ride_post_path(ride_posts(:one), tab: "chat"))
    [ "button[aria-label='Back to trip']", "#chat_message_form button" ].each do |selector|
      rect = find(selector).evaluate_script("this.getBoundingClientRect().toJSON()")
      %w[width height].each { |dimension| assert_operator rect[dimension], :>=, 44 }
    end
  end

  test "avatar preview keeps the last valid image when a replacement is invalid" do
    sign_in(users(:one))
    resize_and_visit(390, settings_profile_path)
    image = Tempfile.new([ "preview", ".png" ])
    image.binmode
    image.write(Vips::Image.black(200, 20).pngsave_buffer)
    image.flush
    attach_file "Upload Avatar", image.path
    assert_selector "img[data-avatar-preview-target='preview']"
    preview_src = find("img[data-avatar-preview-target='preview']")[:src]
    rect = find("img[data-avatar-preview-target='preview']").evaluate_script("this.getBoundingClientRect().toJSON()")
    assert_equal [ 80, 80 ], rect.values_at("width", "height")

    invalid = nil
    [ ".txt", ".png" ].each do |extension|
      invalid = Tempfile.new([ "invalid-preview", extension ])
      invalid.write("Not an image")
      invalid.flush
      attach_file "Upload Avatar", invalid.path
      page.document.synchronize do
        raise Capybara::ExpectationNotMet if find("input[type='file']").evaluate_script("this.validity.valid")
      end
      assert_equal preview_src, find("img[data-avatar-preview-target='preview']")[:src]
      assert find("img[data-avatar-preview-target='preview']").evaluate_script("this.complete && this.naturalWidth > 0")
      invalid.close!
    end
  ensure
    image&.close!
    invalid&.close! unless invalid&.closed?
  end

  private

  def sign_in(user)
    visit new_session_path
    fill_in "Email Address", with: user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_selector "[data-notification-count]", visible: :all
    assert_current_path root_path
  end

  def resize_and_visit(width, path, theme = "light")
    page.driver.resize(width, 844)
    visit path
    page.execute_script("document.documentElement.classList.toggle('dark', arguments[0] === 'dark')", theme)
  end

  def assert_document_contained
    assert page.evaluate_script("document.scrollingElement.scrollWidth <= document.scrollingElement.clientWidth + 1"), "Document must not scroll horizontally"
  end

  def assert_contained(selector, container, text: false, parent: false)
    bounds = page.evaluate_script(<<~JS, selector, container, text, parent)
      ((selector, container, measureText, parent) => [...document.querySelectorAll(selector)].filter(el => el.getClientRects().length).map(el => {
        const outer = parent ? el.parentElement : el.closest(container) || document.querySelector(container);
        const range = document.createRange(); range.selectNodeContents(el);
        const r = measureText ? range.getBoundingClientRect() : el.getBoundingClientRect(), p = outer.getBoundingClientRect();
        return {text:el.textContent.slice(0,50), left:r.left, right:r.right, outerLeft:p.left, outerRight:p.right, scroll:el.scrollWidth, width:el.clientWidth};
      }))(arguments[0], arguments[1], arguments[2], arguments[3])
    JS
    assert_not_empty bounds, selector
    bounds.each do |r|
      assert_operator r["left"], :>=, r["outerLeft"] - 1, "#{selector} left edge: #{r['text']}"
      assert_operator r["right"], :<=, r["outerRight"] + 1, "#{selector} right edge: #{r['text']}"
      assert_operator r["scroll"], :<=, r["width"] + 1, "#{selector} clips content: #{r['text']}" unless text
    end
  end

  def assert_text_contrast(selector, threshold)
    ratio = page.evaluate_script(<<~JS, selector)
      (() => {
        const el = document.querySelector(arguments[0]);
        const canvas = document.createElement('canvas'); canvas.width = canvas.height = 1; const ctx = canvas.getContext('2d');
        const rgb = color => {ctx.fillStyle = color; ctx.fillRect(0,0,1,1); return [...ctx.getImageData(0,0,1,1).data].slice(0,3);};
        const luminance = values => values.map(v => {v/=255;return v<=0.04045?v/12.92:((v+0.055)/1.055)**2.4;}).reduce((s,v,i)=>s+v*[0.2126,0.7152,0.0722][i],0);
        const foreground = luminance(rgb(getComputedStyle(el).color));
        const background = luminance(rgb(getComputedStyle(document.body).backgroundColor));
        return (Math.max(foreground,background)+0.05)/(Math.min(foreground,background)+0.05);
      })()
    JS
    assert_operator ratio, :>=, threshold
  end
end
