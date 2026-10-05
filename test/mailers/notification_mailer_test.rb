require "test_helper"

class NotificationMailerTest < ActionMailer::TestCase
  include Rails.application.routes.url_helpers

  test "upheld and dismissed decisions send their own outcome and restriction snapshot" do
    incident = NoShowIncident.create!(ride_post: ride_posts(:one), user: users(:one), occurred_at: 1.day.ago)

    [ :upheld, :dismissed ].each do |status|
      decision = incident.decisions.create!(
        reviewer: users(:two), previous_status: :pending, status: status,
        reason: "PRIVATE MODERATION REASON", booking_freeze_until: status == :upheld ? 2.days.from_now : nil
      )
      notification = Notification.create!(
        recipient: users(:one), actor: users(:two), notifiable: decision,
        event_name: "incident.resolved", delivery_key: "incident_resolved:decision:#{decision.id}"
      )

      mail = NotificationMailer.with(notification: notification).event_notification

      assert_equal [ users(:one).email_address ], mail.to
      assert_equal "Decision on a no-show report on Pasabaya", mail.subject
      [ mail.html_part, mail.text_part ].each do |part|
        assert_includes part.body.decoded, notification.summary
        assert_includes part.body.decoded, notification.incident_booking_restriction_summary
        assert_includes part.body.decoded, notification_url(notification, **NotificationMailer.default_url_options)
        assert_not_includes part.body.decoded, decision.reason
        assert_not_includes part.body.decoded, users(:two).first_name
      end
    end
  end

  test "legacy incident mail keeps its ride link" do
    ride = ride_posts(:one)
    notification = Notification.create!(
      recipient: users(:one), notifiable: ride, event_name: "incident.resolved",
      delivery_key: "legacy_incident_mail"
    )

    mail = NotificationMailer.with(notification: notification).event_notification

    assert_equal "Update on your reported incident on Pasabaya", mail.subject
    [ mail.html_part, mail.text_part ].each do |part|
      assert_includes part.body.decoded, "A decision has been reached regarding your reported incident on Pasabaya."
      assert_includes part.body.decoded, ride_post_url(ride, **NotificationMailer.default_url_options)
    end
  end
end
