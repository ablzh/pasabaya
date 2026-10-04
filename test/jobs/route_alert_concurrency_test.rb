require "test_helper"
require "timeout"

class RouteAlertConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "overlapping match jobs record only one event for the same active subscription" do
    passenger = users(:two)
    ride = ride_posts(:one)
    subscription = RouteSubscription.create!(user: passenger, origin_id: ride.origin_id, destination_id: ride.destination_id)
    ready = Queue.new
    start = Queue.new
    results = Queue.new

    # Pause at the database boundary after each worker has found candidates,
    # so both jobs see the same active subscription before either consumes it.
    observer = lambda do |*arguments|
      event = ActiveSupport::Notifications::Event.new(*arguments)
      worker = Thread.current[:route_alert_concurrency_worker]
      if worker && !worker[:ready] && event.payload[:sql].start_with?('SELECT "route_subscriptions".')
        worker[:ready] = true
        ready << true
        Timeout.timeout(10) { start.pop }
      end
    end
    workers = []
    ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
      workers = 2.times.map do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            Thread.current[:route_alert_concurrency_worker] = {}
            RouteAlertJob.perform_now(ride.id)
            results << :completed
          rescue StandardError => error
            results << error
          ensure
            Thread.current[:route_alert_concurrency_worker] = nil
          end
        end
      end
      Timeout.timeout(10) { 2.times { ready.pop } }
      2.times { start << true }
      workers.each { |worker| worker.join(10) }
    end

    assert workers.none?(&:alive?), "Both match workers must finish"
    outcomes = 2.times.map { results.pop }
    assert_equal [ :completed, :completed ], outcomes, outcomes.map(&:to_s).join("\n")
    assert subscription.reload.fulfilled?
    assert_equal 1, Notification.where(route_subscription: subscription).count
    assert_no_difference("Notification.count") { RouteAlertJob.perform_now(ride.id) }
  ensure
    2.times { start << true } if start
    workers&.each { |worker| worker.join(10) }
    Notification.where(route_subscription: subscription).destroy_all if subscription
    subscription&.destroy!
  end
end
