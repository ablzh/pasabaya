require "test_helper"
require "action_cable/subscription_adapter/solid_cable"

class RideCancellationBroadcastJobTest < ActiveJob::TestCase
  setup do
    @ride = ride_posts(:one)
    @booking = bookings(:one)
    @driver = @ride.user
    @passenger = @booking.passenger
    Bookings::AcceptService.call(@booking, actor: @driver)
    RidePosts::CancelService.call(@ride, actor: @driver)
    @dispatch = @ride.ride_post_dispatches.cancellation_refresh.sole
  end

  test "a cable failure leaves committed cancellation and retryable publication" do
    published = []
    with_stubbed_method(Turbo::StreamsChannel, :broadcast_refresh_to, ->(stream) {
      raise IOError, "Cable unavailable" if published.any?
      published << stream
    }) do
      assert_raises(IOError) { RideCancellationBroadcastJob.new.perform(@dispatch.id) }
    end

    assert @ride.reload.canceled?
    assert @booking.reload.canceled?
    assert @booking.accepted_at
    assert Notification.exists?(delivery_key: "ride_canceled:#{@ride.id}:booking:#{@booking.id}")
    assert_equal 1, @dispatch.reload.failure_count
    assert_equal "IOError", @dispatch.last_error
    assert @dispatch.failed_at
    assert_equal [ [ @ride, :chat ] ], published

    streams = []
    with_stubbed_method(Turbo::StreamsChannel, :broadcast_refresh_to, ->(stream) { streams << stream }) do
      perform_enqueued_jobs(only: RideCancellationBroadcastJob) { RidePostDispatchRecoveryJob.perform_now }
      RideCancellationBroadcastJob.perform_now(@dispatch.id)
    end

    assert_not RidePostDispatch.exists?(@dispatch.id)
    assert_equal [ [ @ride, :chat ], [ @driver, :chats ], [ @passenger, :chats ] ].to_set, streams.to_set
    assert_equal 3, streams.size
  end

  test "repeated cancellation does not add publication or notification work" do
    assert_no_difference([ "RidePostDispatch.count", "Notification.count" ]) do
      RidePosts::CancelService.call(@ride, actor: @ride.user)
    end
  end

  test "a Solid Cable database failure preserves retryable cancellation publication" do
    adapter = ActionCable::SubscriptionAdapter::SolidCable.new(ActionCable.server)

    with_stubbed_method(ActionCable.server, :pubsub, adapter) do
      with_stubbed_method(SolidCable::Message, :with_connection, -> { raise IOError, "Cable database unavailable" }) do
        assert_raises(IOError) { RideCancellationBroadcastJob.new.perform(@dispatch.id) }
      ensure
        # Drain an asynchronous writer before restoring the database boundary.
        adapter.instance_variable_get(:@broadcaster)&.shutdown
      end
    end

    assert @ride.reload.canceled?
    assert @booking.reload.canceled?
    assert_equal 1, @dispatch.reload.failure_count
    assert_equal "IOError", @dispatch.last_error
    assert @dispatch.failed_at
  end
end
