# frozen_string_literal: true

require "test_helper"

module RouteSubscriptions
  class MatchServiceTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

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

    test "resubscribing to the same dated hub search records another one shot event safely" do
      hub = communities(:two)
      CommunityMembership.create!(user: @driver, community: hub, institutional_email: "driver@up.edu.ph", verified_at: Time.current)
      ride = RidePost.create!(user: @driver, origin: @origin, destination: @destination, seats: 3,
                             departure_date: Date.current + 2, departure_choice: :morning,
                             visibility: :hub_only, community: hub, status: :active)
      filters = { user: @subscriber, origin: @origin, destination: @destination, departure_date: ride.departure_date, community: hub }
      first = RouteSubscription.create!(filters)
      MatchService.call(ride)
      second = RouteSubscription.create!(filters)

      assert_difference("Notification.count", 1) { MatchService.call(ride) }
      assert_equal [ "fulfilled", "fulfilled" ], RouteSubscription.where(id: [ first.id, second.id ]).pluck(:status)
      assert_no_difference("Notification.count") { MatchService.call(ride) }
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

    test "reopening seats on full ride triggers matching active subscription" do
      sub = RouteSubscription.create!(
        user: @subscriber,
        origin: @origin,
        destination: @destination
      )

      ride = RidePost.create!(
        user: @driver,
        origin: @origin,
        destination: @destination,
        post_type: :offering,
        seats: 1,
        departure_date: 2.days.from_now.to_date,
        departure_choice: :morning,
        status: :active
      )

      other_passenger = User.create!(
        email_address: "other_passenger@example.com",
        password: "password",
        first_name: "Other",
        last_name: "Passenger"
      )

      booking = Booking.create!(
        ride_post: ride,
        passenger: other_passenger,
        status: :accepted
      )
      ride.update_columns(remaining_seats: 0, status: RidePost.statuses[:fulfilled])
      assert_not ride.reload.bookable?

      assert_enqueued_with(job: RouteAlertJob, args: [ ride.id ]) do
        Bookings::CancelService.call(booking, actor: other_passenger)
      end

      assert ride.reload.bookable?
      assert_equal 1, ride.remaining_seats

      assert_difference("Notification.count", 1) do
        MatchService.call(ride)
      end

      assert sub.reload.fulfilled?
      assert_equal ride, sub.ride_post
      notif = Notification.last
      assert_equal @subscriber, notif.recipient
      assert_equal "route.alert", notif.event_name
    end

    test "changing a ride route triggers subscription for new route" do
      new_dest = Location.create!(name: "Quezon City", location_type: :city, slug: "quezon-city")

      sub_old = RouteSubscription.create!(
        user: @subscriber,
        origin: @origin,
        destination: @destination
      )

      other_user = User.create!(
        email_address: "other_sub@example.com",
        password: "password",
        first_name: "Sub",
        last_name: "Two"
      )
      sub_new = RouteSubscription.create!(
        user: other_user,
        origin: @origin,
        destination: new_dest
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
      # Fulfill old route
      MatchService.call(ride)
      assert sub_old.reload.fulfilled?

      # Driver updates route to new destination
      assert_enqueued_with(job: RouteAlertJob, args: [ ride.id ]) do
        ride.update!(destination: new_dest)
      end

      assert_difference("Notification.count", 1) do
        MatchService.call(ride.reload)
      end

      assert sub_new.reload.fulfilled?
      assert_equal ride, sub_new.ride_post
    end

    test "editing non-matching criteria such as notes does not schedule route alerts" do
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

      assert_no_enqueued_jobs(only: RouteAlertJob) do
        ride.update!(notes: "Bring warm clothes and water")
      end
    end

    test "unbookable rides do not trigger route alerts" do
      draft_ride = RidePost.create!(
        user: @driver,
        origin: @origin,
        destination: @destination,
        post_type: :offering,
        seats: 3,
        status: :draft
      )

      assert_no_enqueued_jobs(only: RouteAlertJob) do
        draft_ride.update!(seats: 4)
      end

      assert_no_difference("Notification.count") do
        MatchService.call(draft_ride)
      end
    end
  end
end
