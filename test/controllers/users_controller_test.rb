require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "profile renders external Facebook link" do
    sign_in_as(users(:one))
    get user_url(users(:one))

    assert_response :success
    assert_select "a[href='https://facebook.com/juan'][target='_blank'][rel='noopener noreferrer']"
  end
end
