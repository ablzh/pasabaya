# frozen_string_literal: true

require "test_helper"

class Email::ConfirmationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: "confirm_test@example.com",
      unconfirmed_email: "new_confirmed@example.com",
      password: "password123",
      first_name: "Confirm",
      last_name: "User"
    )
  end

  test "confirms email address with valid token" do
    token = @user.generate_token_for(:email_confirmation)

    get email_confirmation_url(token: token)

    assert_redirected_to new_session_path
    assert_equal "Email address confirmed!", flash[:notice]
    assert_equal "new_confirmed@example.com", @user.reload.email_address
    assert_nil @user.unconfirmed_email
  end

  test "rejects confirmation token for deleted user accounts" do
    token = @user.generate_token_for(:email_confirmation)
    Users::AnonymizeService.call(@user)

    get email_confirmation_url(token: token)

    assert_redirected_to root_path
    assert_equal "The confirmation link is invalid or has expired. Request a new email confirmation in Account Settings.", flash[:alert]
  end

  test "rejects confirmation when user has been marked deleted" do
    # Even if unconfirmed_email were artificially retained on a deleted user
    token = @user.generate_token_for(:email_confirmation)
    @user.update_columns(deleted_at: Time.current)

    get email_confirmation_url(token: token)

    assert_redirected_to root_path
    assert_equal "This account has been deleted.", flash[:alert]
  end

  test "rejects invalid confirmation token" do
    get email_confirmation_url(token: "invalid_token_value")

    assert_redirected_to root_path
    assert_equal "The confirmation link is invalid or has expired. Request a new email confirmation in Account Settings.", flash[:alert]
  end

  test "rejects confirmation loaded before deletion" do
    stale_user = User.find(@user.id)
    token = stale_user.generate_token_for(:email_confirmation)
    assert Users::AnonymizeService.call(@user)

    with_stubbed_method(User, :find_by_token_for, stale_user) do
      get email_confirmation_url(token: token)
    end

    assert_redirected_to root_path
    assert_equal "The confirmation link is invalid or has expired. Request a new email confirmation in Account Settings.", flash[:alert]
    assert_match(/@deleted\.pasabaya\.app\z/, @user.reload.email_address)
  end
end
