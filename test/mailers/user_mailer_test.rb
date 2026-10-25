require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  include Rails.application.routes.url_helpers

  setup do
    @driver = users(:one)
    @origin = locations(:one)
    @destination = locations(:two)
    @schedule = create_schedule(@driver)
  end

  test "welcome guides new members to search offers and profile settings in both formats" do
    mail = UserMailer.welcome(@driver)

    assert_equal [ @driver.email_address ], mail.to
    [ mail.html_part, mail.text_part ].each do |part|
      body = part.body.decoded
      assert_includes body, @driver.first_name
      assert_includes body, ride_posts_url(**UserMailer.default_url_options)
      assert_includes body, new_ride_post_url(**UserMailer.default_url_options)
      assert_includes body, settings_profile_url(**UserMailer.default_url_options)
    end
  end

  test "ride upgrade includes current owned schedules and direct review links in both formats" do
    draft = create_schedule(@driver, status: :draft, ladies_only: true, departure_choice: :flexible, departure_clock: nil)
    other_drivers_schedule = create_schedule(users(:two))
    mail = UserMailer.with(user_id: @driver.id, schedule_ids: [ @schedule.id, draft.id, other_drivers_schedule.id ]).ride_upgrade

    assert_equal [ @driver.email_address ], mail.to
    [ mail.html_part, mail.text_part ].each do |part|
      body = part.body.decoded
      assert_includes body, @schedule.schedule_display
      assert_includes body, draft.schedule_display
      assert_includes body, @schedule.end_date.to_fs(:long)
      assert_includes body, edit_ride_schedule_url(@schedule, **UserMailer.default_url_options)
      assert_includes body, edit_ride_schedule_url(draft, **UserMailer.default_url_options)
      assert_includes body, settings_profile_url(**UserMailer.default_url_options)
      assert_includes body, "private draft"
      assert_includes body, terms_url(**UserMailer.default_url_options)
      assert_includes body, privacy_url(**UserMailer.default_url_options)
      assert_includes body, "October 23, 2026"
      assert_includes body, "privacy@pasabaya.app"
      assert_not_includes body, edit_ride_schedule_url(other_drivers_schedule, **UserMailer.default_url_options)
    end
  end

  test "queued ride upgrade reloads changed schedules and the current mailbox" do
    UserMailer.with(user_id: @driver.id, schedule_ids: [ @schedule.id ]).ride_upgrade.deliver_later
    @schedule.update!(departure_clock: "09:30", end_date: Date.current + 45)
    @driver.update!(email_address: "updated@example.com")

    assert_emails 1 do
      perform_enqueued_jobs
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "updated@example.com" ], mail.to
    [ mail.html_part, mail.text_part ].each do |part|
      assert_includes part.body.decoded, "09:30"
      assert_includes part.body.decoded, @schedule.end_date.to_fs(:long)
    end
  end

  test "dated ride upgrade includes only owned rides and no recurring defaults or expiry" do
    ride = @driver.ride_posts.create!(origin: @origin, destination: @destination, seats: 5,
      departure_date: Date.current + 2, departure_choice: :exact_time, exact_departure_time: "12:00")
    other_ride = ride_posts(:two)
    mail = UserMailer.with(user_id: @driver.id, ride_ids: [ ride.id, other_ride.id ]).ride_upgrade

    assert_equal [ @driver.email_address ], mail.to
    [ mail.html_part, mail.text_part ].each do |part|
      body = part.body.decoded
      assert_includes body, ride.departure_display
      assert_includes body, edit_ride_post_url(ride, **UserMailer.default_url_options)
      assert_not_includes body, edit_ride_post_url(other_ride, **UserMailer.default_url_options)
      assert_not_includes body, "30 days"
      assert_not_includes body, "Monday–Friday"
    end
  end

  test "queued ride upgrade is not sent to a deleted account" do
    UserMailer.with(user_id: @driver.id, schedule_ids: [ @schedule.id ]).ride_upgrade.deliver_later
    @driver.update_column(:deleted_at, Time.current)

    assert_no_emails do
      perform_enqueued_jobs
    end
  end

  test "queued ride upgrade is not sent to a banned account" do
    UserMailer.with(user_id: @driver.id, schedule_ids: [ @schedule.id ]).ride_upgrade.deliver_later
    @driver.update_column(:banned_at, Time.current)

    assert_no_emails do
      perform_enqueued_jobs
    end
  end

  test "ride upgrade is not sent when no requested schedules belong to the recipient" do
    other_schedule = create_schedule(users(:two))

    assert_no_emails do
      UserMailer.with(user_id: @driver.id, schedule_ids: [ other_schedule.id ]).ride_upgrade.deliver_now
    end
  end

  test "platform update includes find and offer links without a transferred ride deadline" do
    mail = UserMailer.with(user_id: @driver.id).platform_update

    assert_equal [ @driver.email_address ], mail.to
    [ mail.html_part, mail.text_part ].each do |part|
      body = part.body.decoded
      assert_includes body, ride_posts_url(**UserMailer.default_url_options)
      assert_includes body, new_ride_post_url(**UserMailer.default_url_options)
      assert_includes body, terms_url(**UserMailer.default_url_options)
      assert_includes body, privacy_url(**UserMailer.default_url_options)
      assert_includes body, "October 23, 2026"
      assert_includes body, "privacy@pasabaya.app"
      assert_not_includes body, @schedule.end_date.to_fs(:long)
      assert_not_includes body, "30 days"
    end
  end

  test "queued platform update uses the current mailbox" do
    UserMailer.with(user_id: @driver.id).platform_update.deliver_later
    @driver.update!(email_address: "updated@example.com")

    assert_emails 1 do
      perform_enqueued_jobs
    end

    assert_equal [ "updated@example.com" ], ActionMailer::Base.deliveries.last.to
  end

  test "queued platform update is not sent to a deleted account" do
    UserMailer.with(user_id: @driver.id).platform_update.deliver_later
    @driver.update_column(:deleted_at, Time.current)

    assert_no_emails do
      perform_enqueued_jobs
    end
  end

  test "queued platform update is not sent to a banned account" do
    UserMailer.with(user_id: @driver.id).platform_update.deliver_later
    @driver.update_column(:banned_at, Time.current)

    assert_no_emails do
      perform_enqueued_jobs
    end
  end

  test "platform update is not sent when the recipient no longer exists" do
    assert_no_emails do
      UserMailer.with(user_id: -1).platform_update.deliver_now
    end
  end

  private

  def create_schedule(user, **attributes)
    user.ride_schedules.create!({
      origin: @origin, destination: @destination, weekday_ids: [ 1, 2, 3, 4, 5 ],
      departure_choice: :exact_time, departure_clock: "08:00", seats: 3,
      status: :active, end_date: Date.current + 30
    }.merge(attributes))
  end
end
