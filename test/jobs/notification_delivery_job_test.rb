# frozen_string_literal: true

require "test_helper"

class NotificationDeliveryJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper
  include Rails.application.routes.url_helpers
  setup do
    @recipient = users(:one)
    @actor = users(:two)
    @booking = bookings(:one)
    @notification = Notification.create!(
      recipient: @recipient,
      actor: @actor,
      notifiable: @booking,
      event_name: "booking.requested",
      delivery_key: "test_delivery_#{SecureRandom.hex(6)}",
      delivery_status: :pending
    )
  end

  test "delivers pending notification and sends email for email events" do
    assert_emails 1 do
      NotificationDeliveryJob.perform_now(@notification.id)
    end

    @notification.reload
    assert_equal "delivered", @notification.delivery_status
    assert_not_nil @notification.delivered_at
    mail = ActionMailer::Base.deliveries.last
    ride = @booking.ride_post
    assert_equal [ ride.user.email_address ], mail.to
    assert_includes mail.subject, ride.origin.name
    assert_includes mail.subject, ride.destination.name
    [ mail.html_part, mail.text_part ].each do |part|
      assert_includes part.body.decoded, @actor.first_name
      assert_includes part.body.decoded, ride.origin.name
      assert_includes part.body.decoded, ride.destination.name
      assert_includes part.body.decoded, ride.departure_display
      assert_includes part.body.decoded, ride_post_url(ride, **NotificationMailer.default_url_options)
    end
  end

  test "skips delivery if already delivered" do
    @notification.update_columns(delivery_status: Notification.delivery_statuses[:delivered], delivered_at: Time.current)

    assert_emails 0 do
      NotificationDeliveryJob.perform_now(@notification.id)
    end
  end
end
