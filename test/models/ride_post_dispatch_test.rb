require "test_helper"
require "open3"

class RidePostDispatchTest < ActiveSupport::TestCase
  test "a false enqueue result is recorded for recovery" do
    with_stubbed_method(RouteAlertJob, :perform_later, false) do
      dispatch = ride_posts(:one).ride_post_dispatches.create!(operation: :route_alert)

      assert_equal 1, dispatch.reload.failure_count
      assert_equal "ActiveJob::EnqueueError", dispatch.last_error
      assert dispatch.failed_at
    end
  end

  test "deleting a ride removes its outstanding work" do
    ride = RidePost.create!(user: users(:one), status: :draft)
    dispatch = ride.ride_post_dispatches.create!(operation: :route_alert)

    ride.delete

    assert_not RidePostDispatch.exists?(dispatch.id)
  end

  test "failed matching keeps work until a successful retry" do
    dispatch = ride_posts(:one).ride_post_dispatches.create!(operation: :route_alert)
    with_stubbed_method(RouteSubscriptions::MatchService, :call, ->(*) { raise IOError, "Matching interrupted" }) do
      assert_raises(IOError) { RouteAlertJob.new.perform(dispatch.ride_post_id) }
    end

    assert_equal 1, dispatch.reload.failure_count
    assert_equal "IOError", dispatch.last_error

    RouteAlertJob.perform_now(dispatch.ride_post_id)
    assert_not RidePostDispatch.exists?(dispatch.id)
  end

  test "matching does not erase work added while the job runs" do
    ride = ride_posts(:one)
    earlier = ride.ride_post_dispatches.create!(operation: :route_alert)
    later = nil

    with_stubbed_method(RouteSubscriptions::MatchService, :call, ->(*) { later = ride.ride_post_dispatches.create!(operation: :route_alert) }) do
      RouteAlertJob.perform_now(ride.id)
    end

    assert_not RidePostDispatch.exists?(earlier.id)
    assert RidePostDispatch.exists?(later.id)
  end

  test "matching rechecks current eligibility before consuming durable work" do
    ride = ride_posts(:one)
    bookings(:one).destroy!
    subscription = RouteSubscription.create!(user: users(:two), origin_id: ride.origin_id, destination_id: ride.destination_id)
    assert subscription.matches?(ride)
    dispatch = ride.ride_post_dispatches.create!(operation: :route_alert)
    ride.user.update_columns(banned_at: Time.current)

    assert_no_difference("Notification.count") { RouteAlertJob.perform_now(ride.id) }

    assert subscription.reload.active?
    assert_not RidePostDispatch.exists?(dispatch.id)
  end

  test "dispatches respect real outer commits and rollbacks" do
    # Transactional fixtures cannot demonstrate the outermost commit boundary.
    Dir.mktmpdir("pasabaya-dispatch-commit-") do |directory|
      script = File.join(directory, "commit.rb")
      File.write(script, <<~'RUBY')
        ActiveRecord::Schema.verbose = false
        load Rails.root.join("db/schema.rb")
        ActiveJob::Base.queue_adapter = :test
        driver = User.create!(email_address: "driver@example.com", password: "password", first_name: "Driver", last_name: "One")
        passenger = User.create!(email_address: "passenger@example.com", password: "password", first_name: "Passenger", last_name: "Two")
        origin, destination, other = [ "Origin", "Destination", "Other" ].map { |name| Location.create!(name: name, location_type: :city) }
        original_enqueue = RouteAlertJob.method(:perform_later)
        enqueue_states = []
        RouteAlertJob.define_singleton_method(:perform_later) do |*|
          enqueue_states << ActiveRecord::Base.connection.transaction_open?
          raise IOError, "Queue unavailable"
        end
        ride = nil
        RidePost.transaction do
          ride = RidePost.create!(user: driver, origin: origin, destination: destination, seats: 3,
                                 departure_date: Date.current + 2, departure_choice: :morning, status: :active)
          raise "Missing transactional work" unless ride.ride_post_dispatches.route_alert.count == 1
          raise "Enqueued before outer commit" unless enqueue_states.empty?
        end
        raise "Enqueue did not run after commit" unless enqueue_states == [ false ]
        dispatch = ride.ride_post_dispatches.route_alert.sole
        raise "Queue failure was not durable" unless dispatch.failure_count == 1 && dispatch.last_error == "IOError"
        RouteAlertJob.define_singleton_method(:perform_later, original_enqueue)
        RouteAlertJob.perform_now(ride.id)

        ActiveJob::Base.queue_adapter.enqueued_jobs.clear
        RidePost.transaction do
          ride.update!(destination: other)
          raise "Missing route edit work" unless ride.ride_post_dispatches.route_alert.exists?
          raise ActiveRecord::Rollback
        end
        raise "Rolled-back edit survived" unless ride.reload.destination_id == destination.id
        raise "Rolled-back route work survived" if RidePostDispatch.exists?
        raise "Rolled-back route work enqueued" unless ActiveJob::Base.queue_adapter.enqueued_jobs.empty?

        booking = Bookings::CreateService.call(ride_post: ride, passenger: passenger)
        Bookings::AcceptService.call(booking, actor: driver)
        remaining_seats = ride.reload.remaining_seats
        before_notifications = Notification.count
        ActiveJob::Base.queue_adapter.enqueued_jobs.clear
        broadcasts = []
        Turbo::StreamsChannel.define_singleton_method(:broadcast_refresh_to) do |stream|
          raise "Broadcast before outer commit" if ActiveRecord::Base.connection.transaction_open?
          broadcasts << stream
        end
        RidePost.transaction do
          RidePosts::CancelService.call_many(RidePost.where(id: ride.id), actor: driver)
          raise "Missing transactional cancellation work" unless RidePostDispatch.cancellation_refresh.exists?
          raise "Cancellation enqueued before commit" unless ActiveJob::Base.queue_adapter.enqueued_jobs.empty?
          raise "Cancellation broadcast before commit" unless broadcasts.empty?
          raise ActiveRecord::Rollback
        end
        raise "Rolled-back cancellation survived" unless ride.reload.active? && booking.reload.accepted?
        raise "Rolled-back notifications survived" unless Notification.count == before_notifications
        raise "Rolled-back cancellation work survived" if RidePostDispatch.exists?
        raise "Rolled-back cancellation enqueued" unless ActiveJob::Base.queue_adapter.enqueued_jobs.empty?

        RidePost.transaction do
          RidePosts::CancelService.call(ride, actor: driver)
          raise "Cancellation enqueued before outer commit" unless ActiveJob::Base.queue_adapter.enqueued_jobs.empty?
          raise "Cancellation broadcast before commit" unless broadcasts.empty?
        end
        dispatch = RidePostDispatch.cancellation_refresh.sole
        queued = ActiveJob::Base.queue_adapter.enqueued_jobs
        raise "Missing committed cancellation job" unless queued.any? { |job| job[:job] == RideCancellationBroadcastJob && job[:args] == [ dispatch.id ] }
        raise "Cancellation inventory changed" unless ride.reload.remaining_seats == remaining_seats
        raise "Accepted history lost" unless booking.reload.canceled? && booking.accepted_at
        raise "Notification missing" unless Notification.exists?(delivery_key: "ride_canceled:#{ride.id}:booking:#{booking.id}")
        RideCancellationBroadcastJob.perform_now(dispatch.id)
        expected = [ [ ride, :chat ], [ driver, :chats ], [ passenger, :chats ] ]
        raise "Wrong cancellation streams" unless broadcasts.size == expected.size && (expected - broadcasts).empty?
        raise "Completed work retained" if RidePostDispatch.exists?
      RUBY
      output, status = Open3.capture2e(
        { "DATABASE_URL" => "sqlite3:#{directory}/commit.sqlite3", "RAILS_ENV" => "test" },
        RbConfig.ruby, Rails.root.join("bin/rails").to_s, "runner", script
      )
      assert status.success?, output
    end
  end
end
