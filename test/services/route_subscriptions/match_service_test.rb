# frozen_string_literal: true

require "test_helper"

module RouteSubscriptions
  class MatchServiceTest < ActiveSupport::TestCase
    setup do
      @subscriber = users(:two)
      @driver = users(:one)
      @origin = locations(:one)
      @destination = locations(:two)
    end

    test "fulfills subscription upon matching ride publication and sends notification" do
      sub = RouteSubscription.create!(
        user: @subscriber,
        origin: @origin,
        destination: @destination,
        departure_date: 2.days.from_now.to_date
      )

      ride = RidePost.create!(
        user: @driver,
        origin: @origin,
        destination: @destination,
        post_type: :offering,
        seats: 3,
        departure_date: 2.days.from_now.to_date,
        departure_choice: :morning,
        status: :active
      )

      assert_difference("Notification.count", 1) do
        MatchService.call(ride)
      end

      assert sub.reload.fulfilled?
      assert_equal ride, sub.ride_post
      assert_not_nil sub.consumed_at

      notif = Notification.last
      assert_equal @subscriber, notif.recipient
      assert_equal "route.alert", notif.event_name
      assert_equal ride, notif.notifiable

      # Repeated call does not send duplicate alert
      assert_no_difference("Notification.count") do
        MatchService.call(ride)
      end
    end

    test "does not alert canceled or expired subscriptions" do
      canceled_sub = RouteSubscription.create!(
        user: @subscriber,
        origin: @origin,
        destination: @destination,
        status: :canceled
      )

      ride = RidePost.create!(
        user: @driver,
        origin: @origin,
        destination: @destination,
        post_type: :offering,
        seats: 3,
        departure_date: 2.days.from_now.to_date,
        departure_choice: :morning,
        status: :active
      )

      assert_no_difference("Notification.count") do
        MatchService.call(ride)
      end
    end

    test "rechecks audience access before notifying" do
      male_subscriber = users(:one)
      female_driver = users(:two)

      sub = RouteSubscription.create!(
        user: male_subscriber,
        origin: @origin,
        destination: @destination
      )

      ladies_ride = RidePost.create!(
        user: female_driver,
        origin: @origin,
        destination: @destination,
        post_type: :offering,
        seats: 3,
        departure_date: 2.days.from_now.to_date,
        departure_choice: :morning,
        ladies_only: true,
        status: :active
      )

      assert_no_difference("Notification.count") do
        MatchService.call(ladies_ride)
      end
      assert sub.reload.active?
    end
  end
end
