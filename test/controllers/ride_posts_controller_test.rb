require "test_helper"

class RidePostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @ride_post = ride_posts(:one)
    sign_in_as(@user)
  end

  test "should get index with empty state (blank slate) when no search params are provided" do
    # Sign out because index is accessible to the public/unauthenticated users
    sign_out
    get ride_posts_url
    assert_response :success
    assert_select "h3", "Where are you heading?"
  end

  test "should get index with results when search params match active posts" do
    sign_out
    get ride_posts_url, params: {
      post_type: @ride_post.post_type,
      origin_id: @ride_post.origin_id,
      destination_id: @ride_post.destination_id
    }
    assert_response :success
    assert_select "h3", "#{@ride_post.origin.name} → #{@ride_post.destination.name}"
  end

  test "should get new" do
    get new_ride_post_url
    assert_response :success
  end

  test "should create ride_post" do
    assert_difference("RidePost.count", 1) do
      post ride_posts_url, params: {
        ride_post: {
          post_type: "offering",
          origin_id: locations(:one).id,
          destination_id: locations(:two).id,
          departure_time: 1.day.from_now,
          seats: 3,
          notes: "Leaving early morning"
        }
      }
    end

    assert_redirected_to ride_post_url(RidePost.last)
  end

  test "should show ride_post" do
    sign_out
    get ride_post_url(@ride_post)
    assert_response :success
  end

  test "should get edit" do
    get edit_ride_post_url(@ride_post)
    assert_response :success
  end

  test "should update ride_post" do
    patch ride_post_url(@ride_post), params: {
      ride_post: {
        seats: 4,
        notes: "Updated seats count"
      }
    }
    assert_redirected_to ride_post_url(@ride_post)
  end

  test "should destroy ride_post" do
    assert_difference("RidePost.count", -1) do
      delete ride_post_url(@ride_post)
    end

    assert_redirected_to ride_posts_url
  end

  test "should get route page with dynamic SEO tags" do
    sign_out

    origin = @ride_post.origin
    destination = @ride_post.destination

    get route_rides_url(origin_slug: origin.slug, destination_slug: destination.slug)

    assert_response :success
    assert_select "title", text: /Carpool from #{origin.name} to #{destination.name}/
  end
end
