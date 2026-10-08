require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "should get signup page for guest" do
    get sign_up_url
    assert_response :success
    assert_select "input[type='checkbox'][name='user[registration_acceptance]'][required]"
    assert_select "label", text: /I confirm that I am at least 18 years old and agree to the Terms of Service and Privacy Policy/
    assert_select "label a[href=?]", terms_path, text: "Terms of Service"
    assert_select "label a[href=?]", privacy_path, text: "Privacy Policy"
  end

  test "registration rejects missing or false age and policy acceptance and preserves input" do
    [ nil, "0", "false" ].each do |acceptance|
      attributes = {
        first_name: "Liza", last_name: "Soberano", email_address: "attestation@example.com",
        password: "password123", password_confirmation: "password123"
      }
      attributes[:registration_acceptance] = acceptance unless acceptance.nil?

      assert_no_difference("User.count") do
        post sign_up_url, params: { user: attributes }
      end

      assert_response :unprocessable_content
      assert_select "#user_registration_acceptance_error", text: "Confirm that you are at least 18 and agree to the Terms of Service and Privacy Policy."
      assert_select "a[href='#user_registration_acceptance']"
      assert_select "input[name='user[first_name]'][value='Liza']"
      assert_select "input[name='user[email_address]'][value='attestation@example.com']"
    end
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
            password_confirmation: "password123",
            registration_acceptance: "1"
          }
        }
      end
    end

    assert_redirected_to root_url
    assert_equal "Welcome to Pasabaya! Your account was successfully created.", flash[:notice]
  end

  test "should create user without facebook_profile_url" do
    assert_difference("User.count", 1) do
      post sign_up_url, params: {
        user: {
          first_name: "Bea",
          last_name: "Alonzo",
          email_address: "bea@example.com",
          facebook_profile_url: "",
          password: "password123",
          password_confirmation: "password123",
          registration_acceptance: "1"
        }
      }
    end

    assert_redirected_to root_url
    user = User.find_by(email_address: "bea@example.com")
    assert_nil user.facebook_profile_url
  end

  test "should reject signup with unsafe facebook_profile_url" do
    assert_no_difference("User.count") do
      post sign_up_url, params: {
        user: {
          first_name: "Bea",
          last_name: "Alonzo",
          email_address: "bea_unsafe@example.com",
          facebook_profile_url: "http://evil.com/phishing",
          password: "password123",
          password_confirmation: "password123",
          registration_acceptance: "1"
        }
      }
    end

    assert_response :unprocessable_content
    assert_select "p", text: /Enter an HTTPS link to your Facebook profile/
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

  test "successful registration records server time and policy version despite forged values" do
    travel_to Time.zone.local(2026, 10, 3, 12, 0) do
      post sign_up_url, params: { user: {
        first_name: "Liza", last_name: "Soberano", email_address: "recorded@example.com",
        password: "password123", password_confirmation: "password123", registration_acceptance: "1",
        registration_accepted_at: "1990-01-01", registration_policy_version: "forged"
      } }

      assert_redirected_to root_url
      user = User.find_by!(email_address: "recorded@example.com")
      assert_equal Time.current, user.registration_accepted_at
      assert_equal "2026-10-03", user.registration_policy_version
    end
  end

  test "should redirect already logged in user trying to signup" do
    sign_in_as(users(:one))

    get sign_up_url
    assert_redirected_to root_url
    assert_equal "You are already signed in.", flash[:alert]
  end
end
