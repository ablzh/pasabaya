# frozen_string_literal: true

require "test_helper"

class Settings::ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "invalid avatar renders field errors and retains the saved avatar and entered name" do
    @user.avatar.attach(io: StringIO.new(Vips::Image.black(2, 2).pngsave_buffer), filename: "avatar.png", content_type: "image/png")
    original_blob_id = @user.avatar.blob.id
    file = Tempfile.new([ "invalid-avatar", ".txt" ])
    file.write("Not an image")
    file.rewind

    patch settings_profile_url, params: { user: { first_name: "Entered name", avatar: Rack::Test::UploadedFile.new(file.path, "text/plain") } }

    assert_response :unprocessable_content
    assert_select "input[name='user[first_name]'][value='Entered name']"
    assert_select "#user_avatar_error", text: "Choose a JPEG, PNG, or WebP image."
    assert_select "img[data-avatar-preview-target='preview']"
    assert_equal original_blob_id, @user.reload.avatar.blob.id
  ensure
    file&.close!
  end

  test "corrupt image is rejected without replacing the saved avatar" do
    file = Tempfile.new([ "corrupt-avatar", ".png" ])
    file.binmode
    file.write("\x89PNG\r\n\x1A\n".b + "broken image data")
    file.rewind

    patch settings_profile_url, params: { user: { avatar: Rack::Test::UploadedFile.new(file.path, "image/png") } }

    assert_response :unprocessable_content
    assert_select "#user_avatar_error", text: "This image couldn’t be read. Choose another JPEG, PNG, or WebP image."
    assert_not @user.reload.avatar.attached?
  ensure
    file&.close!
  end

  test "direct-upload avatar accepts a real image and rejects a corrupt replacement" do
    image = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(Vips::Image.black(2, 2).pngsave_buffer), filename: "direct.png", content_type: "image/png")
    patch settings_profile_url, params: { user: { avatar: image.signed_id } }
    assert_redirected_to settings_profile_url
    assert_equal image.id, @user.reload.avatar.blob.id

    corrupt = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("\x89PNG\r\n\x1A\n".b + "broken image data"), filename: "corrupt.png", content_type: "image/png", identify: false)
    patch settings_profile_url, params: { user: { avatar: corrupt.signed_id } }
    assert_response :unprocessable_content
    assert_select "#user_avatar_error", text: "This image couldn’t be read. Choose another JPEG, PNG, or WebP image."
    assert_equal image.id, @user.reload.avatar.blob.id
  end

  test "removes facebook_profile_url and hides profile action" do
    assert @user.safe_facebook_profile_url?
    assert_nil @user.registration_accepted_at

    patch settings_profile_url, params: {
      user: {
        facebook_profile_url: ""
      }
    }

    assert_redirected_to settings_profile_url
    assert_equal "Profile updated successfully.", flash[:notice]

    @user.reload
    assert_nil @user.facebook_profile_url
    assert_nil @user.registration_accepted_at
    assert_nil @user.registration_policy_version
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
    assert_select "p", text: /Enter an HTTPS link to your Facebook profile/
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
