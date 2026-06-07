require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end
  # 1. Accessing fixture data to test custom methods
  test "initials returns capitalized first letters of first and last name" do
    user = users(:one) # "Juan Dela Cruz"
    assert_equal "JD", user.initials
  end

  # 2. Testing validations (negative path)
  test "invalid without facebook_profile_url" do
    user = users(:one)
    user.facebook_profile_url = nil

    assert_not user.valid?
    assert_includes user.errors[:facebook_profile_url], "can't be blank"
  end

  # 3. Testing validations (positive path)
  test "valid with correct facebook_profile_url format" do
    user = users(:one)
    user.facebook_profile_url = "https://facebook.com/custom_username"

    assert user.valid?
  end
end
