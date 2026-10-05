require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @notification = notifications(:one)
  end

  test "avatar contains the accessible notification badge and a compact profile menu" do
    sign_in_as(@user)
    get root_url
    assert_select "nav > div > ul a[href='#{notifications_path}']", count: 0
    assert_select "button[aria-label='Account menu'][aria-describedby='account-notification-count'] [data-notification-count] span[aria-label='1 unread notification']", text: "1"
    assert_select "#profile-content a", count: 5
    { "Profile" => user_path(@user), "Settings" => settings_profile_path,
      "Notifications" => notifications_path, "Hubs" => communities_path, "Sign out" => session_path }.each do |label, path|
      assert_select "#profile-content a[href='#{path}']", text: /#{label}/
    end
    assert_select "#profile-content a[href='#{trips_path}']", count: 0
    assert_select "#profile-content a.sm\\:hidden[href='#{communities_path}']", text: "Hubs"
    assert_select "nav a[href='#{communities_path}']"
    assert_select "nav a[href='#{chats_path}']"
  end

  test "authenticated user can view their notifications" do
    sign_in_as(@user)

    get notifications_url
    assert_response :success
  end

  test "viewing a notification marks it as read and redirects to target" do
    sign_in_as(@user)
    assert_not @notification.read?

    get notification_url(@notification)

    assert @notification.reload.read?
    assert_redirected_to ride_post_url(@notification.notifiable.ride_post)
  end

  test "unauthenticated user cannot access notifications" do
    get notifications_url
    assert_redirected_to new_session_url
  end

  test "marking a notification read with HTML redirects using GET" do
    sign_in_as(@user)
    patch mark_as_read_notification_url(@notification)
    assert_response :see_other
    assert_redirected_to notifications_url
    assert @notification.reload.read?
  end

  test "viewing a notification when notifiable was deleted redirects to rides index" do
    sign_in_as(@user)
    ride = RidePost.create!(
      user: users(:two),
      origin: locations(:one),
      destination: locations(:two),
      post_type: :offering,
      seats: 2,
      departure_time: 2.days.from_now,
      expected_arrival_at: 2.days.from_now + 2.hours,
      status: :active
    )
    orphan_notification = Notification.create!(
      recipient: @user,
      notifiable: ride,
      event_name: "ride.canceled",
      delivery_key: "orphan_test_key",
      delivery_status: :delivered
    )
    ride.destroy!

    get notification_url(orphan_notification)

    assert orphan_notification.reload.read?
    assert_redirected_to ride_posts_url
    assert_equal "The trip is no longer available.", flash[:notice]
  end

  test "recipient can read the decision without private moderation evidence" do
    notification = incident_decision_notification(status: :upheld, booking_freeze_until: 2.days.from_now)
    sign_in_as(@user)

    get notification_url(notification)

    assert_response :success
    assert notification.reload.read?
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_includes response.headers["Cache-Control"], "private"
    assert_select "h1", text: "No-show report decision"
    assert_includes response.body, "A no-show report about your participation was upheld."
    assert_includes response.body, notification.incident_booking_restriction_summary
    assert_includes response.body, locations(:one).name
    assert_includes response.body, locations(:two).name
    assert_not_includes response.body, "PRIVATE MODERATION REASON"
    assert_not_includes response.body, ride_posts(:two).notes
  end

  test "another recipient cannot read an incident decision notification" do
    notification = incident_decision_notification(status: :dismissed)
    sign_in_as(users(:two))

    get notification_url(notification)

    assert_response :not_found
    assert_not notification.reload.read?
  end

  test "decision ownership is checked even if a notification has the wrong recipient" do
    notification = incident_decision_notification(status: :upheld)
    notification.update!(recipient: users(:two))
    sign_in_as(users(:two))

    get notification_url(notification)

    assert_response :not_found
    assert_not_includes response.body, "PRIVATE MODERATION REASON"
  end

  test "an older decision identifies its replacement and the current incident outcome" do
    notification = incident_decision_notification(status: :upheld)
    incident = notification.notifiable.no_show_incident
    incident.update!(status: :dismissed)
    incident.decisions.create!(
      reviewer: users(:two), previous_status: :upheld, status: :dismissed,
      reason: "PRIVATE REVISED REASON"
    )
    sign_in_as(@user)

    get notification_url(notification)

    assert_response :success
    assert_select "[role='status']", text: /A later decision replaced this update.*Current incident outcome: Dismissed/m
    assert_includes response.body, "A no-show report about your participation was upheld."
    assert_not_includes response.body, "PRIVATE REVISED REASON"
  end

  test "incident decision summaries appear in the notifications list" do
    notification = incident_decision_notification(status: :dismissed)
    sign_in_as(@user)

    get notifications_url

    assert_response :success
    assert_select "#notification_#{notification.id}", text: /A no-show report about your participation was dismissed\./
    assert_not_includes response.body, "PRIVATE MODERATION REASON"
  end

  test "a retained decision remains readable after its reviewer and reason are scrubbed" do
    notification = incident_decision_notification(status: :dismissed)
    NoShowIncidentDecision.where(id: notification.notifiable_id).update_all(reviewer_id: nil, reason: nil)
    sign_in_as(@user)

    get notification_url(notification)

    assert_response :success
    assert_includes response.body, "A no-show report about your participation was dismissed."
    assert_not_includes response.body, "PRIVATE MODERATION REASON"
  end

  test "legacy incident notifications still open their ride" do
    notification = Notification.create!(
      recipient: @user, notifiable: ride_posts(:two), event_name: "incident.resolved",
      delivery_key: "legacy_incident_notification"
    )
    sign_in_as(@user)

    get notification_url(notification)

    assert_redirected_to ride_post_url(ride_posts(:two))
  end

  private

  def incident_decision_notification(status:, booking_freeze_until: nil)
    incident = NoShowIncident.create!(ride_post: ride_posts(:two), user: @user, status: status, occurred_at: 1.day.ago)
    decision = incident.decisions.create!(
      reviewer: users(:two), previous_status: :pending, status: status,
      reason: "PRIVATE MODERATION REASON", booking_freeze_until: booking_freeze_until
    )
    Notification.create!(
      recipient: @user, actor: users(:two), notifiable: decision,
      event_name: "incident.resolved", delivery_key: "incident_resolved:decision:#{decision.id}"
    )
  end
end
