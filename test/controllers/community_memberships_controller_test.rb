# frozen_string_literal: true

require "test_helper"

class CommunityMembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @community = communities(:one) # accenture.com
    @user = User.create!(
      email_address: "test_candidate@example.com",
      password: "password",
      first_name: "Candidate",
      last_name: "User",
      facebook_profile_url: "https://facebook.com/candidate"
    )
  end

  test "create requires authentication" do
    post community_memberships_url(@community), params: { institutional_email: "cand@accenture.com" }
    assert_redirected_to new_session_url
  end

  test "create enqueues verification email and redirects with notice" do
    sign_in_as(@user)
    assert_enqueued_emails 1 do
      post community_memberships_url(@community), params: { institutional_email: "cand@accenture.com" }
    end
    assert_redirected_to community_url(@community)
    follow_redirect!
    assert_match(/Verification email sent/, response.body)

    membership = @user.community_memberships.find_by(community: @community)
    assert_not_nil membership
    assert_not membership.verified?
  end

  test "create rejects mismatched email domain" do
    sign_in_as(@user)
    assert_no_emails do
      post community_memberships_url(@community), params: { institutional_email: "cand@otherdomain.com" }
    end
    assert_redirected_to community_url(@community)
    follow_redirect!
    assert_match(/must match the community domain/, response.body)
  end

  test "verify confirms membership with valid token" do
    membership = CommunityMembership.create!(
      user: @user,
      community: @community,
      institutional_email: "cand@accenture.com"
    )
    token = membership.generate_token_for(:verification)

    sign_in_as(@user)
    get verify_community_membership_url(token: token)

    assert_redirected_to community_url(@community)
    follow_redirect!
    assert_match(/Your email has been verified!/, response.body)
    assert membership.reload.verified?
  end

  test "verify rejects invalid token" do
    get verify_community_membership_url(token: "invalid-token-123")
    assert_redirected_to root_url
    follow_redirect!
    assert_match(/The verification link is invalid or has expired/, response.body)
  end

  test "destroy revokes membership" do
    membership = CommunityMembership.create!(
      user: @user,
      community: @community,
      institutional_email: "cand@accenture.com",
      verified_at: Time.current
    )
    sign_in_as(@user)

    delete community_membership_url(@community, membership)
    assert_redirected_to community_url(@community)
    follow_redirect!
    assert_match(/You have left the #{@community.name} community/, response.body)

    assert membership.reload.revoked_at.present?
    assert_not membership.verified?
  end
end
