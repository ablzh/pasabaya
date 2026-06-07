require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "should get signup page for guest" do
    get sign_up_url
    assert_response :success
  end

  test "should create user, log them in, and enqueue welcome email" do
    assert_difference("User.count", 1) do
      assert_enqueued_emails 1 do
        post sign_up_url, params: {
          user: {
            first_name: "Liza",
            last_name: "Soberano",
            email_address: "liza@example.com",
            facebook_profile_url: "https://facebook.com/liza",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end
    end

    assert_redirected_to root_url
    assert_equal "Welcome to Pasabaya! Your account was successfully created.", flash[:notice]
  end

  test "should not create user and render errors on validation failure" do
    assert_no_difference("User.count") do
      post sign_up_url, params: {
        user: {
          first_name: "",
          email_address: "invalid-email",
          password: "foo",
          password_confirmation: "bar"
        }
      }
    end

    assert_response :unprocessable_content
  end

  test "should redirect already logged in user trying to signup" do
    sign_in_as(users(:one))
    
    get sign_up_url
    assert_redirected_to root_url
    assert_equal "You are already signed in.", flash[:alert]
  end
end
