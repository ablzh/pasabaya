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

  test "should redirect search with both origin and destination to seo route" do
    sign_out
    get ride_posts_url, params: {
      post_type: @ride_post.post_type,
      origin_id: @ride_post.origin_id,
      destination_id: @ride_post.destination_id
    }

    # Проверяем, что произошел редирект на красивый SEO-URL
    assert_redirected_to route_rides_url(
                           origin_slug: @ride_post.origin.slug,
                           destination_slug: @ride_post.destination.slug,
                           post_type: @ride_post.post_type
                         )
  end

  test "should get index with results when only origin is searched (no redirect)" do
    sign_out
    get ride_posts_url, params: {
      origin_id: @ride_post.origin_id
    }

    # Поиск по одному критерию не должен редиректить
    assert_response :success
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
          expected_arrival_at: 1.day.from_now + 2.hours,
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

  test "should allow another signed-in user to show ride_post" do
    get ride_post_url(ride_posts(:two))
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

  test "draft offers cannot be viewed by anonymous or non-owner users" do
    @ride_post.update_columns(status: RidePost.statuses[:draft])

    sign_out
    get ride_post_url(@ride_post)
    assert_redirected_to ride_posts_url

    get ride_post_url(@ride_post, format: :json)
    assert_response :forbidden

    sign_in_as(users(:two))
    get ride_post_url(@ride_post)
    assert_redirected_to ride_posts_url

    # Owner can view draft
    sign_in_as(@ride_post.user)
    get ride_post_url(@ride_post)
    assert_response :success
  end

  test "cannot destroy ride_post with accepted bookings" do
    booking = bookings(:one)
    booking.update_columns(status: Booking.statuses[:accepted])

    assert_no_difference("RidePost.count") do
      delete ride_post_url(@ride_post)
    end

    assert_redirected_to ride_post_url(@ride_post)
  end

  test "should not get edit for ride_post owned by another user" do
    other_post = ride_posts(:two)
    get edit_ride_post_url(other_post)
    assert_response :not_found
  end

  test "should not update ride_post owned by another user and leave record unchanged" do
    other_post = ride_posts(:two)
    assert_no_changes -> { other_post.reload.attributes } do
      patch ride_post_url(other_post), params: {
        ride_post: {
          seats: 4,
          notes: "Unauthorized modification"
        }
      }
    end
    assert_response :not_found
  end

  test "should not destroy ride_post owned by another user and leave record intact" do
    other_post = ride_posts(:two)
    assert_no_difference("RidePost.count") do
      delete ride_post_url(other_post)
    end
    assert_response :not_found
    assert RidePost.exists?(other_post.id)
  end

  test "should get route page with dynamic SEO tags and H1" do
    sign_out

    origin = @ride_post.origin
    destination = @ride_post.destination
    expected_url = route_rides_url(origin_slug: origin.slug, destination_slug: destination.slug)

    get expected_url

    assert_response :success
    assert_select "title", text: /Carpool from #{origin.name} to #{destination.name}/
    assert_select "h1", text: /Carpool from #{origin.name} to #{destination.name}/
    assert_select "link[rel='canonical'][href='#{expected_url}']"
    assert_select "meta[property='og:url'][content='#{expected_url}']"
  end

  test "should show ride_post with noindex robots tag" do
    sign_out
    expected_url = ride_post_url(@ride_post)
    get expected_url
    assert_response :success

    assert_select "title", text: /Ride from #{@ride_post.origin.name} to #{@ride_post.destination.name}/
    assert_select "meta[name='robots'][content*='noindex']"
    assert_select "link[rel='canonical'][href='#{expected_url}']"
    assert_select "meta[property='og:url'][content='#{expected_url}']"

    assert_select "meta[name='description']" do |elements|
      assert_match /#{@ride_post.user.first_name}/, elements.first["content"]
    end
  end

  test "owner can cancel their trip" do
    assert_not @ride_post.canceled?

    patch cancel_ride_post_url(@ride_post)

    assert_redirected_to ride_post_url(@ride_post)
    assert_equal "Trip was successfully canceled.", flash[:notice]
    assert @ride_post.reload.canceled?
  end

  test "show page displays cancel trip button for owner" do
    get ride_post_url(@ride_post)
    assert_response :success
    assert_select "form[action='#{cancel_ride_post_path(@ride_post)}']" do
      assert_select "button", text: "Cancel Trip"
    end
  end

  test "handles cancel service error gracefully" do
    original_call = RidePosts::CancelService.method(:call)
    RidePosts::CancelService.define_singleton_method(:call) do |*|
      raise RidePosts::CancelService::Error, "Cannot cancel this trip"
    end

    patch cancel_ride_post_url(@ride_post)
    assert_redirected_to ride_post_url(@ride_post)
    assert_equal "Cannot cancel this trip", flash[:alert]
  ensure
    RidePosts::CancelService.define_singleton_method(:call, original_call)
  end

  test "non-owner cannot cancel someone else's trip" do
    other_post = ride_posts(:two)
    patch cancel_ride_post_url(other_post)
    assert_response :not_found
    assert_not other_post.reload.canceled?
  end
end
