require "test_helper"

class RidePostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @ride_post = ride_posts(:one)
  end

  test "should get index" do
    get ride_posts_url
    assert_response :success
  end

  test "should get new" do
    get new_ride_post_url
    assert_response :success
  end

  test "should create ride_post" do
    assert_difference("RidePost.count") do
      post ride_posts_url, params: { ride_post: {} }
    end

    assert_redirected_to ride_post_url(RidePost.last)
  end

  test "should show ride_post" do
    get ride_post_url(@ride_post)
    assert_response :success
  end

  test "should get edit" do
    get edit_ride_post_url(@ride_post)
    assert_response :success
  end

  test "should update ride_post" do
    patch ride_post_url(@ride_post), params: { ride_post: {} }
    assert_redirected_to ride_post_url(@ride_post)
  end

  test "should destroy ride_post" do
    assert_difference("RidePost.count", -1) do
      delete ride_post_url(@ride_post)
    end

    assert_redirected_to ride_posts_url
  end
end
