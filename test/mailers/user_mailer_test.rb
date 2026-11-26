require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  include Rails.application.routes.url_helpers

  setup do
    @driver = users(:one)
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

  test "community survey includes survey url, facebook link, upou context and personal signoff in both formats" do
    mail = UserMailer.with(user_id: @driver.id).community_survey

    assert_equal [ @driver.email_address ], mail.to
    assert_equal "Help shape what we build next for Pasabaya (10-min survey)", mail.subject
    [ mail.html_part, mail.text_part ].each do |part|
      body = part.body.decoded
      assert_includes body, @driver.first_name
      assert_includes body, UserMailer::COMMUNITY_SURVEY_URL
      assert_includes body, UserMailer::FACEBOOK_PAGE_URL
      assert_includes body, "University of the Philippines Open University (UPOU)"
      assert_includes body, "Founder of Pasabaya.app &"
      assert_includes body, "UPOU Student"
    end
  end

  test "queued community survey is not sent to a deleted or banned account" do
    UserMailer.with(user_id: @driver.id).community_survey.deliver_later
    @driver.update_column(:deleted_at, Time.current)

    assert_no_emails do
      perform_enqueued_jobs
    end

    @driver.update_columns(deleted_at: nil, banned_at: Time.current)
    UserMailer.with(user_id: @driver.id).community_survey.deliver_later

    assert_no_emails do
      perform_enqueued_jobs
    end
  end

  test "community survey is not sent when recipient does not exist" do
    assert_no_emails do
      UserMailer.with(user_id: -1).community_survey.deliver_now
    end
  end
end
