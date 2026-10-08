# frozen_string_literal: true

require "test_helper"

class CommunitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @community = communities(:two)
    @user = users(:one)
  end

  test "index succeeds for guest and shows disclaimer and request hub Facebook link" do
    get communities_url
    assert_response :success
    assert_select "h1", /Community Carpool Hubs/
    assert_includes response.body, "Pasabaya is an independent community platform and is not officially affiliated with, endorsed by, or partnered with any listed university or institution. Hubs are community-led spaces verified via institutional email domains."
    assert_select "a[href='https://www.facebook.com/people/Pasabayaapp-Carpooling-for-the-Community/61589209230043/']", text: "Request a Community Hub"
    assert_includes response.body, "institution name and official email domain"
  end

  test "index succeeds for authenticated user" do
    sign_in_as(@user)
    get communities_url
    assert_response :success
  end

  test "show displays community hub and disclaimer" do
    get community_url(@community)
    assert_response :success
    assert_select "h1", @community.name
    assert_includes response.body, "Pasabaya is an independent community platform"
  end

  test "show redirects legacy up-diliman slug to canonical UP community" do
    get "/communities/up-diliman"
    assert_redirected_to community_path(@community)
  end
end
