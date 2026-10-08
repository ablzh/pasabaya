require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "create with valid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_response :unprocessable_content
    assert_select "input[name='email_address'][value='#{@user.email_address}']"
    assert_nil cookies[:session_id]
  end

  test "destroy" do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end

  test "unsafe return paths cannot redirect to another host" do
    get new_session_path, params: { return_to: "/\\evil.example" }
    post session_path, params: { email_address: @user.email_address, password: "password" }
    assert_redirected_to root_path
  end

  test "rejects authentication for deleted accounts even with valid password" do
    @user.update_columns(deleted_at: Time.current)
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to new_session_path
    assert_equal "This account has been deleted.", flash[:alert]
    assert_nil cookies[:session_id]
  end

  test "rejects a user deleted after credentials were authenticated" do
    stale_user = User.find(@user.id)
    assert Users::AnonymizeService.call(@user)

    with_stubbed_method(User, :authenticate_by, stale_user) do
      assert_no_difference("Session.count") do
        post session_path, params: { email_address: stale_user.email_address, password: "password" }
      end
    end

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end
end
