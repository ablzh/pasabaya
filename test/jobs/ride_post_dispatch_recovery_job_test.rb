require "test_helper"

class RidePostDispatchRecoveryJobTest < ActiveJob::TestCase
  test "the sweep retries matching and cancellation work independently" do
    ride = ride_posts(:one)
    route = ride.ride_post_dispatches.create!(operation: :route_alert, created_at: 3.days.ago)
    cancellation = ride.ride_post_dispatches.create!(operation: :cancellation_refresh, recipient_ids: [ ride.user_id ])

    with_stubbed_method(RouteAlertJob, :perform_later, ->(*) { raise IOError, "Queue unavailable" }) do
      assert_enqueued_with(job: RideCancellationBroadcastJob, args: [ cancellation.id ]) do
        RidePostDispatchRecoveryJob.perform_now
      end
    end

    assert_equal 1, route.reload.failure_count
    assert_equal 0, cancellation.reload.failure_count
    assert_enqueued_with(job: RouteAlertJob, args: [ ride.id ]) { RidePostDispatchRecoveryJob.perform_now }
  end
end
