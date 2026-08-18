require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get home with active carpool routes" do
    get root_url
    assert_response :success
    assert_select "h2", text: /Active Carpool Routes/
  end

  test "should get privacy" do
    get privacy_url
    assert_response :success
  end

  test "should get terms" do
    get terms_url
    assert_response :success
  end
end
