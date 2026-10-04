require "test_helper"

class DepartureDatesTest < ActionDispatch::IntegrationTest
  test "malformed exact departure times show validation errors without changing the published schedule" do
    ride = ride_posts(:one)
    sign_in_as(ride.user)
    original_departure = ride.departure_time

    [ "25:99", "invalid", "08:00garbage" ].each do |time|
      patch ride_post_url(ride), params: {
        ride_post: { departure_date: Date.tomorrow, departure_choice: :exact_time, exact_departure_time: time, expected_arrival_at: "" }
      }
      assert_response :unprocessable_content
      assert_select "#error_explanation", text: /Departure time must be a valid time/
      assert_equal original_departure, ride.reload.departure_time
    end
  end

  test "exact early morning and approximate offers appear on their Philippine departure date" do
    travel_to Time.zone.local(2026, 10, 4, 12) do
      exact = ride_posts(:one)
      exact.update!(departure_date: Date.new(2026, 10, 5), exact_departure_time: "01:00", expected_arrival_at: nil)
      approximate = ride_posts(:two)
      approximate.update!(departure_date: Date.new(2026, 10, 5), departure_choice: :morning, expected_arrival_at: nil)

      get ride_posts_url(departure_date: "2026-10-05")
      assert_response :success
      assert_select "#ride_post_#{exact.id}"
      assert_select "#ride_post_#{approximate.id}"

      get ride_posts_url(departure_date: "2026-10-04")
      assert_select "#ride_post_#{exact.id}", count: 0
      assert_select "#ride_post_#{approximate.id}", count: 0
    end
  end
end
