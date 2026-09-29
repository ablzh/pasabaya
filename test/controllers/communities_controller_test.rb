# frozen_string_literal: true

require "test_helper"

class CommunitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @community = communities(:one)
    @user = users(:one)
  end

  test "index succeeds for guest" do
    get communities_url
    assert_response :success
    assert_select "h1", /Community Carpool Hubs/
  end

  test "index succeeds for authenticated user" do
    sign_in_as(@user)
    get communities_url
    assert_response :success
  end

  test "show displays community hub" do
    get community_url(@community)
    assert_response :success
    assert_select "h1", @community.name
  end
end
