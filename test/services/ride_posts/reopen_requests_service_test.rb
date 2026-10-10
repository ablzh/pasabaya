# frozen_string_literal: true

require "test_helper"

module RidePosts
  class ReopenRequestsServiceTest < ActiveSupport::TestCase
    setup do
      @ride = ride_posts(:one)
      @driver = @ride.user
      @other_user = users(:two)
    end

    test "driver can reopen seat requests on a closed trip" do
      CloseRequestsService.call(@ride, actor: @driver)
      assert @ride.reload.requests_closed_at.present?
      assert_not @ride.bookable?

      ReopenRequestsService.call(@ride, actor: @driver)
      assert_nil @ride.reload.requests_closed_at
      assert @ride.bookable?
    end

    test "non-driver actor cannot reopen seat requests" do
      CloseRequestsService.call(@ride, actor: @driver)
      assert_raises(ReopenRequestsService::Error) do
        ReopenRequestsService.call(@ride, actor: @other_user)
      end
      assert @ride.reload.requests_closed_at.present?
    end

    test "cannot reopen requests on canceled trip" do
      @ride.update_columns(requests_closed_at: Time.current, status: RidePost.statuses[:canceled])
      assert_raises(ReopenRequestsService::Error) do
        ReopenRequestsService.call(@ride, actor: @driver)
      end
      assert @ride.reload.requests_closed_at.present?
    end

    test "cannot reopen requests on completed trip" do
      @ride.update_columns(requests_closed_at: Time.current, status: RidePost.statuses[:completed])
      assert_raises(ReopenRequestsService::Error) do
        ReopenRequestsService.call(@ride, actor: @driver)
      end
      assert @ride.reload.requests_closed_at.present?
    end

    test "cannot reopen requests on draft trip" do
      @ride.update_columns(requests_closed_at: Time.current, status: RidePost.statuses[:draft])
      assert_raises(ReopenRequestsService::Error) do
        ReopenRequestsService.call(@ride, actor: @driver)
      end
      assert @ride.reload.requests_closed_at.present?
    end

    test "cannot reopen requests past booking cutoff" do
      @ride.update_columns(requests_closed_at: Time.current, departure_time: 1.hour.ago)
      assert_raises(ReopenRequestsService::Error) do
        ReopenRequestsService.call(@ride, actor: @driver)
      end
    end

    test "returns ride unchanged if requests are already open" do
      assert_nil @ride.requests_closed_at
      result = ReopenRequestsService.call(@ride, actor: @driver)
      assert_equal @ride, result
      assert_nil @ride.reload.requests_closed_at
    end
  end
end
