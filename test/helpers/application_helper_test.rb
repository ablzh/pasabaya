# frozen_string_literal: true

require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "user_avatar renders fallback initials when avatar not attached" do
    user = users(:one)
    result = user_avatar(user)

    assert_includes result, user.initials
    assert_includes result, "rounded-full"
  end

  test "user_avatar returns nil when user is blank" do
    assert_nil user_avatar(nil)
  end
end
