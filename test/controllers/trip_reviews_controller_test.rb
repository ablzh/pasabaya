# frozen_string_literal: true

require "test_helper"

class TripReviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @origin = Location.create!(name: "Review Ctrl Origin", location_type: :city)
    @destination = Location.create!(name: "Review Ctrl Dest", location_type: :city)
    @driver = users(:one)
    @passenger = users(:two)
    @outsider = User.create!(
      email_address: "ctrl_outsider@example.com",
      password: "password",
      first_name: "Ctrl",
      last_name: "Outsider",
      facebook_profile_url: "https://facebook.com/ctrloutsider"
    )

    @ride_post = RidePost.create!(
      user: @driver,
      origin: @origin,
      destination: @destination,
      post_type: :offering,
      seats: 3,
      remaining_seats: 2,
      status: :active,
      departure_time: 1.day.from_now,
      expected_arrival_at: 1.day.from_now + 2.hours
    )
    @booking = Booking.create!(ride_post: @ride_post, passenger: @passenger, status: :accepted)
  end

  test "new requires authentication" do
    get new_ride_post_review_url(@ride_post)
    assert_redirected_to new_session_url
  end

  test "new rejects non-participants" do
    sign_in_as(@outsider)
    get new_ride_post_review_url(@ride_post)
    assert_redirected_to ride_post_url(@ride_post)
    follow_redirect!
    assert_match(/Only trip participants can submit a review/, response.body)
  end

  test "new rejects review before trip departure" do
    sign_in_as(@driver)
    get new_ride_post_review_url(@ride_post)
    assert_redirected_to ride_post_url(@ride_post)
    follow_redirect!
    assert_match(/Reviews and no-show reports cannot be submitted before trip departure/, response.body)
  end

  test "new succeeds for participant after trip departure" do
    @ride_post.update_columns(departure_time: 2.hours.ago, expected_arrival_at: 1.hour.ago)
    sign_in_as(@driver)
    get new_ride_post_review_url(@ride_post)
    assert_response :success
    assert_select "h1", /Trip Feedback/
  end

  test "create saves review and creates incident on no-show" do
    @ride_post.update_columns(departure_time: 2.hours.ago, expected_arrival_at: 1.hour.ago)
    sign_in_as(@driver)
    assert_difference -> { TripReview.count }, 1 do
      assert_difference -> { NoShowIncident.count }, 1 do
        post ride_post_reviews_url(@ride_post), params: {
          trip_review: {
            reported_user_id: @passenger.id,
            outcome: "passenger_no_show",
            notes: "Passenger never arrived at pickup point"
          }
        }
      end
    end

    assert_redirected_to ride_post_url(@ride_post)
    follow_redirect!
    assert_match(/Thank you for submitting your trip review/, response.body)

    incident = NoShowIncident.find_by(ride_post: @ride_post, user: @passenger)
    assert_not_nil incident
    assert incident.pending?
  end

  test "wrong no show role cannot create a review or incident" do
    @ride_post.update_columns(departure_time: 2.hours.ago)
    sign_in_as(@driver)
    get new_ride_post_review_url(@ride_post)
    assert_select "option[value='driver_no_show'][disabled]"
    assert_select "option[value='passenger_no_show']:not([disabled])"
    assert_no_difference [ "TripReview.count", "NoShowIncident.count" ] do
      post ride_post_reviews_url(@ride_post), params: {
        trip_review: { reported_user_id: @passenger.id, outcome: "driver_no_show" }
      }
    end
    assert_response :unprocessable_content
    assert_select "li", text: /must describe a passenger/
  end

  test "passenger can review after the driver cancels a departed trip without retaining chat access" do
    @booking.update_columns(accepted_at: 35.days.ago)
    @ride_post.update_columns(departure_time: 35.days.ago, expected_arrival_at: 34.days.ago)
    RidePosts::CancelService.call(@ride_post, actor: @driver)
    @ride_post.update_columns(canceled_at: 35.days.ago)

    assert_not @ride_post.reload.user_authorized_for_chat?(@passenger)
    sign_in_as(@passenger)
    get new_ride_post_review_url(@ride_post)
    assert_response :success

    assert_difference "TripReview.count", 1 do
      post ride_post_reviews_url(@ride_post), params: {
        trip_review: { reported_user_id: @driver.id, outcome: "driver_no_show" }
      }
    end
    assert_redirected_to ride_post_url(@ride_post)
  end

  test "cancellation before departure removes review eligibility" do
    RidePosts::CancelService.call(@ride_post, actor: @driver)
    assert_not @ride_post.participant?(@passenger)
  end

  test "incident failure rolls back its review" do
    @ride_post.update_columns(departure_time: 2.hours.ago, expected_arrival_at: 1.hour.ago)
    sign_in_as(@driver)
    original = NoShowIncident.method(:find_or_create_by!)
    NoShowIncident.define_singleton_method(:find_or_create_by!) do |*|
      raise ActiveRecord::RecordInvalid.new(NoShowIncident.new)
    end

    assert_no_difference "TripReview.count" do
      post ride_post_reviews_url(@ride_post), params: {
        trip_review: { reported_user_id: @passenger.id, outcome: "passenger_no_show" }
      }
    end
    assert_response :unprocessable_content
    assert_select "li", text: /Could not save the incident report/
  ensure
    NoShowIncident.define_singleton_method(:find_or_create_by!, original) if original
  end
  test "draft undated ride and empty departed offer cannot open or submit reviews" do
    sign_in_as(@driver)
    [ { status: :draft, departure_time: nil },
      { status: :active, post_type: :offering, departure_time: nil },
      { status: :active, post_type: :offering, departure_time: 2.hours.ago } ].each do |attributes|
      @ride_post.update_columns(attributes)
      @booking.update_columns(status: Booking.statuses[:pending])
      get new_ride_post_review_url(@ride_post)
      assert_redirected_to ride_post_url(@ride_post)
      assert_no_difference [ "TripReview.count", "NoShowIncident.count" ] do
        post ride_post_reviews_url(@ride_post), params: {
          trip_review: { reported_user_id: @passenger.id, outcome: "completed" }
        }
      end
      assert_redirected_to ride_post_url(@ride_post)
    end
  end

  test "review form labels identify every rendered field" do
    Booking.create!(ride_post: @ride_post, passenger: @outsider, status: :accepted)
    @ride_post.update_columns(departure_time: 2.hours.ago)
    sign_in_as(@driver)
    get new_ride_post_review_url(@ride_post)
    %w[reported_user_id outcome notes].each do |field|
      assert_select "label[for='trip_review_#{field}']", count: 1
      assert_select "#trip_review_#{field}", count: 1
    end
  end
end
