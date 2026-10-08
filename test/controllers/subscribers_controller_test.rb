require "test_helper"

class SubscribersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @subscriber = Subscriber.create!(name: "Legacy Subscriber", email: "legacy@example.test", terms_accepted: true)
    @unsubscribe_token = @subscriber.signed_id(purpose: :unsubscribe)
  end

  test "legacy email links unsubscribe without signing in" do
    get unsubscribe_subscriber_path(@unsubscribe_token)

    assert_response :success
    assert @subscriber.reload.unsubscribed_at.present?
    assert_select "h1", "You’re off the list"
  end

  test "unsubscribe is idempotent" do
    @subscriber.update!(unsubscribed_at: 1.day.ago)
    original_timestamp = @subscriber.unsubscribed_at

    get unsubscribe_subscriber_path(@unsubscribe_token)

    assert_response :success
    assert_equal original_timestamp, @subscriber.reload.unsubscribed_at
  end

  test "invalid or wrong-purpose links cannot unsubscribe" do
    get unsubscribe_subscriber_path(@subscriber.signed_id(purpose: :password_reset))

    assert_response :not_found
    assert_nil @subscriber.reload.unsubscribed_at
  end

  test "the retired waitlist has no creation endpoint" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/subscribers", method: :post)
    end
  end
end
