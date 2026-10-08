# frozen_string_literal: true

require "test_helper"

class CommunityTest < ActiveSupport::TestCase
  test "valid community" do
    community = Community.new(
      name: "JPMorgan Chase",
      domain: "@jpmorgan.com",
      hub_type: :company
    )
    assert community.valid?
    assert_equal "jpmorgan.com", community.domain
    assert_equal "jpmorgan-chase", community.slug
  end

  test "requires presence of name, slug, and domain" do
    community = Community.new
    assert_not community.valid?
    assert_includes community.errors[:name], "can't be blank"
  end

  test "enforces uniqueness of slug and domain" do
    existing = communities(:one)
    duplicate = Community.new(
      name: "Different Name",
      slug: existing.slug,
      domain: existing.domain
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
    assert_includes duplicate.errors[:domain], "has already been taken"
  end

  test "verified_members_count counts only active verified memberships" do
    community = communities(:one)
    initial_count = community.verified_members_count

    new_user = User.create!(
      email_address: "test_member@example.com",
      password: "password",
      first_name: "Test",
      last_name: "Member",
      facebook_profile_url: "https://facebook.com/test"
    )

    unverified = CommunityMembership.create!(
      user: new_user,
      community: community,
      institutional_email: "test_member@accenture.com"
    )
    assert_equal initial_count, community.verified_members_count

    unverified.verify!
    assert_equal initial_count + 1, community.verified_members_count

    unverified.revoke!
    assert_equal initial_count, community.verified_members_count
  end
end
