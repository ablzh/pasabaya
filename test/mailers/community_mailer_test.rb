# frozen_string_literal: true

require "test_helper"

class CommunityMailerTest < ActionMailer::TestCase
  test "verification_email" do
    membership = community_memberships(:one)
    mail = CommunityMailer.verification_email(membership)

    assert_equal [ membership.institutional_email ], mail.to
    assert_equal "Verify your #{membership.community.name} community email on Pasabaya", mail.subject
    assert_includes mail.body.encoded, "Verify My Community Email"
    assert_includes mail.body.encoded, membership.institutional_email
  end
end
