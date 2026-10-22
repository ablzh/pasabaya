# frozen_string_literal: true

require "test_helper"

class CommunityMailerTest < ActionMailer::TestCase
  include Rails.application.routes.url_helpers

  test "verification email addresses the institutional mailbox with a usable verification token" do
    membership = community_memberships(:one)
    mail = CommunityMailer.verification_email(membership)

    assert_equal [ membership.institutional_email ], mail.to
    verification_prefix = verify_community_membership_url(token: "verification-token", **CommunityMailer.default_url_options).delete_suffix("verification-token")
    link = Nokogiri::HTML.fragment(mail.html_part.body.decoded).at_css("a[href^='#{verification_prefix}']")
    assert link
    token = URI::DEFAULT_PARSER.unescape(link["href"].delete_prefix(verification_prefix))
    assert_equal membership, CommunityMembership.find_by_token_for(:verification, token)
    verification_url = verify_community_membership_url(token: token, **CommunityMailer.default_url_options)
    assert_equal verification_url, link["href"]
    assert_includes mail.text_part.body.decoded, verification_url
  end
end
