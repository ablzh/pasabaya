require "test_helper"
require_relative "../test_helpers/rate_limit_test_helper"

class AbuseProtectionTest < ActionDispatch::IntegrationTest
  include RateLimitTestHelper

  test "registration honeypot blocks account creation and welcome mail" do
    get sign_up_path
    assert_select "input[name='user[contact_reference]'][autocomplete='off'][tabindex='-1']"

    assert_no_difference "User.count" do
      assert_no_enqueued_emails do
        post sign_up_path, params: { user: registration_attributes.merge(contact_reference: "Bot-filled field") }
      end
    end
    assert_response :success
    assert_empty response.body
  end

  test "registration accepts an immediately submitted legitimate form" do
    get sign_up_path
    assert_difference "User.count" do
      assert_enqueued_emails 1 do
        post sign_up_path, params: { user: registration_attributes.merge(contact_reference: "") }
      end
    end
    assert_redirected_to root_path
  end

  test "malformed registration parameters are rejected before the honeypot reads them" do
    assert_no_difference "User.count" do
      post sign_up_path, params: { user: "invalid" }
    end
    assert_response :bad_request
  end

  test "signup hourly limit blocks a slow bot that stays below the burst limit" do
    with_rate_limit_cache do
      travel_to Time.zone.local(2026, 10, 5, 12) do
        20.times do
          post sign_up_path, params: { user: registration_attributes.merge(contact_reference: "Bot") }
          assert_response :success
          travel 61.seconds
        end

        assert_no_difference "User.count" do
          post sign_up_path, params: { user: registration_attributes }
        end
        assert_response :too_many_requests
      end
    end
  end

  test "reset cooldown follows normalized recipient across different IPs without revealing accounts" do
    with_rate_limit_cache do |store|
      user = users(:one)
      assert_enqueued_emails 1 do
        post passwords_path, params: { email_address: user.email_address }, env: { "REMOTE_ADDR" => "198.51.100.1" }
      end
      message = flash[:notice]

      assert_no_enqueued_emails do
        post passwords_path, params: { email_address: " #{user.email_address.upcase} " }, env: { "REMOTE_ADDR" => "198.51.100.2" }
      end
      assert_redirected_to new_session_path
      assert_equal message, flash[:notice]
      assert store.instance_variable_get(:@data).keys.none? { |key| key.include?(user.email_address) }

      assert_no_enqueued_emails do
        post passwords_path, params: { email_address: "missing@example.test" }
        post passwords_path, params: { email_address: "missing@example.test" }
      end
      assert_equal message, flash[:notice]

      travel 61.seconds do
        assert_enqueued_emails 1 do
          post passwords_path, params: { email_address: user.email_address }
        end
      end
    end
  end

  test "reset hourly quota survives successive cooldowns and expires" do
    with_rate_limit_cache do
      travel_to Time.zone.local(2026, 10, 5, 12) do
        user = users(:one)
        5.times do
          assert_enqueued_emails 1 do
            post passwords_path, params: { email_address: user.email_address }
          end
          travel 61.seconds
        end
        assert_no_enqueued_emails do
          post passwords_path, params: { email_address: user.email_address }
        end
        assert_redirected_to new_session_path

        travel 1.hour
        assert_enqueued_emails 1 do
          post passwords_path, params: { email_address: user.email_address }
        end
      end
    end
  end

  test "membership resend cooldown does not clear an existing verification" do
    with_rate_limit_cache do
      user = users(:one)
      community = communities(:one)
      sign_in_as(user)
      assert_enqueued_emails 1 do
        post community_memberships_path(community), params: { institutional_email: "member@#{community.domain}" }
      end
      membership = user.community_memberships.find_by!(community: community)
      membership.update!(verified_at: Time.current)

      assert_no_changes -> { membership.reload.verified_at } do
        assert_no_enqueued_emails do
          post community_memberships_path(community), params: { institutional_email: " MEMBER@#{community.domain.upcase} " }
        end
      end
      assert_response :too_many_requests
    end
  end

  test "email change account quota preserves the pending address when a sender rotates recipients" do
    with_rate_limit_cache do
      user = users(:one)
      sign_in_as(user)
      5.times do |index|
        assert_enqueued_emails 1 do
          patch settings_email_path, params: { user: { password_challenge: "password", unconfirmed_email: "change#{index}@example.test" } }
        end
      end

      assert_no_changes -> { user.reload.unconfirmed_email } do
        assert_no_enqueued_emails do
          patch settings_email_path, params: { user: { password_challenge: "password", unconfirmed_email: "blocked@example.test" } }
        end
      end
      assert_response :too_many_requests
    end
  end

  test "email change recipient cooldown also applies to a different sender" do
    with_rate_limit_cache do
      first = users(:one)
      second = users(:two)
      sign_in_as(first)
      assert_enqueued_emails 1 do
        patch settings_email_path, params: { user: { password_challenge: "password", unconfirmed_email: "recipient@example.test" } }
      end

      sign_in_as(second)
      assert_no_changes -> { second.reload.unconfirmed_email } do
        assert_no_enqueued_emails do
          patch settings_email_path, params: { user: { password_challenge: "password", unconfirmed_email: " RECIPIENT@example.test " } }
        end
      end
      assert_response :too_many_requests
    end
  end

  test "membership recipient cooldown also applies to a different sender" do
    with_rate_limit_cache do
      community = communities(:one)
      sign_in_as(users(:one))
      assert_enqueued_emails 1 do
        post community_memberships_path(community), params: { institutional_email: "recipient@#{community.domain}" }
      end

      sign_in_as(users(:two))
      assert_no_enqueued_emails do
        post community_memberships_path(community), params: { institutional_email: " RECIPIENT@#{community.domain.upcase} " }
      end
      assert_response :too_many_requests
    end
  end

  {
    "ride offers" => 10,
    "seat requests" => 20,
    "route alerts" => 20,
    "trip reviews" => 10,
    "chat messages" => 30
  }.each do |kind, quota|
    test "#{kind} are limited per account" do
      user = users(:two)
      ride = ride_posts(:one)
      origin = locations(:one)
      destination = locations(:two)
      if kind == "seat requests"
        bookings(:one).destroy!
      elsif kind == "chat messages" || kind == "trip reviews"
        bookings(:one).update_columns(status: Booking.statuses[:accepted], accepted_at: 2.hours.ago)
      end
      ride.update_columns(departure_time: 1.hour.ago, departure_date: Date.current) if kind == "trip reviews"
      sign_in_as(user)

      path, attributes, count = case kind
      when "ride offers"
        [ ride_posts_path, { ride_post: { origin_id: origin.id, destination_id: destination.id, seats: 2 } }, "RidePost.count" ]
      when "seat requests"
        [ ride_post_bookings_path(ride), { booking: { pickup_notes: "Station" } }, "Booking.count" ]
      when "route alerts"
        [ route_subscriptions_path, { route_subscription: { origin_id: origin.id, destination_id: destination.id } }, "RouteSubscription.count" ]
      when "trip reviews"
        [ ride_post_reviews_path(ride), { trip_review: { reported_user_id: ride.user_id, outcome: :completed } }, "TripReview.count" ]
      when "chat messages"
        [ ride_post_chat_messages_path(ride), { chat_message: { body: "Coordination" } }, "ChatMessage.count" ]
      end

      with_rate_limit_cache do
        quota.times { post path, params: attributes }
        assert_no_difference count do
          post path, params: attributes, env: { "REMOTE_ADDR" => "198.51.100.3" }
        end
        assert_response :too_many_requests
      end
    end
  end

  private

  def registration_attributes
    {
      first_name: "Test", last_name: "Passenger", email_address: "new-person@example.test",
      password: "password123", password_confirmation: "password123", registration_acceptance: "1"
    }
  end
end
