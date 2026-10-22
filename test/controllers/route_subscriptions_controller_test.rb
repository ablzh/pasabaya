# frozen_string_literal: true

require "test_helper"

class RouteSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:two)
    @origin = locations(:one)
    @destination = locations(:two)
  end

  test "create requires authentication" do
    post route_subscriptions_url, params: {
      route_subscription: {
        origin_id: @origin.id,
        destination_id: @destination.id
      }
    }
    assert_redirected_to new_session_url
  end

  test "create subscribes user to route alert" do
    post session_url, params: { email_address: @user.email_address, password: "password" }

    assert_difference("RouteSubscription.count", 1) do
      post route_subscriptions_url, params: {
        route_subscription: {
          origin_id: @origin.id,
          destination_id: @destination.id,
          departure_date: 2.days.from_now.to_date.to_s
        }
      }
    end

    sub = RouteSubscription.last
    assert_equal @user, sub.user
    assert_equal @origin, sub.origin
    assert_equal @destination, sub.destination
    assert_equal 2.days.from_now.to_date, sub.departure_date
    assert sub.active?
  end

  test "destroy cancels route subscription" do
    post session_url, params: { email_address: @user.email_address, password: "password" }

    sub = RouteSubscription.create!(
      user: @user,
      origin: @origin,
      destination: @destination
    )

    delete route_subscription_url(sub)
    assert_redirected_to ride_posts_url
    assert sub.reload.canceled?
  end
end
