# frozen_string_literal: true

require "test_helper"

class Settings::ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "removes facebook_profile_url and hides profile action" do
    assert @user.safe_facebook_profile_url?

    patch settings_profile_url, params: {
      user: {
        facebook_profile_url: ""
      }
    }

    assert_redirected_to settings_profile_url
    assert_equal "Profile updated successfully.", flash[:notice]

    @user.reload
    assert_nil @user.facebook_profile_url
    assert_not @user.safe_facebook_profile_url?

    get user_url(@user)
    assert_response :success
    assert_select "a", text: "View Facebook Profile", count: 0
  end

  test "rejects updating to an unsafe facebook_profile_url" do
    patch settings_profile_url, params: {
      user: {
        facebook_profile_url: "javascript:alert(1)"
      }
    }

    assert_response :unprocessable_content
    assert_select "p", text: /must be an HTTPS Facebook profile URL/
  end

  test "allows updating profile with unchanged legacy invalid facebook_profile_url" do
    @user.update_columns(facebook_profile_url: "http://legacy.facebook.com/outdated:8080")

    patch settings_profile_url, params: {
      user: {
        first_name: "Newname",
        facebook_profile_url: "http://legacy.facebook.com/outdated:8080"
      }
    }

    assert_redirected_to settings_profile_url
    assert_equal "Profile updated successfully.", flash[:notice]
    @user.reload
    assert_equal "Newname", @user.first_name
    assert_equal "http://legacy.facebook.com/outdated:8080", @user.facebook_profile_url
  end
end
