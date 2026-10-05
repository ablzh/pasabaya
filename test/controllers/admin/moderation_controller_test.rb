# frozen_string_literal: true

require "test_helper"

module Admin
  class ModerationControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = User.create!(email_address: "moderator@example.test", password: "password",
        first_name: "Case", last_name: "Reviewer", admin: true)
      @ride = ride_posts(:one)
      @driver = users(:one)
      @passenger = users(:two)
      bookings(:one).update_columns(status: Booking.statuses[:accepted], accepted_at: 3.hours.ago)
      @ride.update_columns(departure_time: 2.hours.ago, expected_arrival_at: 1.hour.ago)
      @review = TripReview.create!(ride_post: @ride, reporter: @driver, reported_user: @passenger,
        outcome: :passenger_no_show, notes: "Passenger missed the agreed pickup.")
      @incident = NoShowIncident.create!(ride_post: @ride, user: @passenger, occurred_at: 2.hours.ago)
    end

    test "all admin reads require authentication and ordinary users cannot access or decide cases" do
      paths = [ admin_root_path, admin_trip_reviews_path, admin_trip_review_path(@review),
        admin_no_show_incidents_path, admin_no_show_incident_path(@incident) ]
      paths.each do |path|
        get path
        assert_redirected_to new_session_path
      end

      sign_in_as(@passenger)
      paths.each do |path|
        get path
        assert_response :forbidden
      end
      assert_no_difference [ "NoShowIncidentDecision.count", "Notification.count" ] do
        patch admin_no_show_incident_path(@incident), params: decision_params
      end
      assert_response :forbidden
      assert @incident.reload.pending?
    end

    test "revoking an admin role or banning the account invalidates existing sessions" do
      sign_in_as(@admin)
      get admin_root_path
      assert_response :success
      User.where(id: @admin.id).update_all(admin: false)
      get admin_trip_review_path(@review)
      assert_response :forbidden

      User.where(id: @admin.id).update_all(admin: true, banned_at: Time.current)
      patch admin_no_show_incident_path(@incident), params: decision_params
      assert_response :forbidden
      assert @incident.reload.pending?
    end

    test "deleted administrators lose their existing session" do
      sign_in_as(@admin)
      User.where(id: @admin.id).update_all(deleted_at: Time.current)
      get admin_root_path
      assert_redirected_to new_session_path
    end

    test "admin pages disable caches and analytics and menu link follows role" do
      sign_in_as(@admin)
      get root_path
      assert_select "a[href=?]", admin_root_path, text: "Administration"
      get admin_trip_reviews_path
      assert_response :success
      assert_equal "private, no-store", response.headers["Cache-Control"]
      assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
      assert_select "meta[name='turbo-cache-control'][content='no-cache']"
      assert_select "meta[name='turbo-visit-control'][content='reload']"
      assert_select "script[src*='umami']", count: 0

      sign_in_as(@passenger)
      get root_path
      assert_select "a[href=?]", admin_root_path, count: 0
    end

    test "reviews can be filtered by either participant and have no write route" do
      second_review = TripReview.create!(ride_post: @ride, reporter: @passenger, reported_user: @driver,
        outcome: :completed, notes: "Trip completed.")
      sign_in_as(@admin)
      get admin_trip_reviews_path, params: { user_id: @passenger.id }
      assert_select "#trip_review_#{@review.id}"
      assert_select "#trip_review_#{second_review.id}"

      get admin_trip_reviews_path, params: { outcome: "passenger_no_show", ride_post_id: @ride.id,
        user_id: @driver.id, from: Date.current.iso8601, to: Date.current.iso8601 }
      assert_select "#trip_review_#{@review.id}"
      assert_select "#trip_review_#{second_review.id}", count: 0

      patch admin_trip_review_path(@review), params: { trip_review: { notes: "Replacement" } }
      assert_response :not_found
      assert_equal "Passenger missed the agreed pickup.", @review.reload.notes
    end

    test "invalid and reversed filters show useful errors without broadening valid filters" do
      sign_in_as(@admin)
      get admin_trip_reviews_path, params: { outcome: "unknown", user_id: "-1", from: "not-a-date", ride_post_id: @ride.id }
      assert_response :success
      assert_select "p", text: "Choose a valid review outcome."
      assert_select "p", text: "User must be a positive number."
      assert_select "p", text: "From date must use YYYY-MM-DD."
      assert_select "#trip_review_#{@review.id}"

      get admin_no_show_incidents_path, params: { from: Date.tomorrow.iso8601, to: Date.yesterday.iso8601 }
      assert_response :success
      assert_select "p", text: "From date cannot be after To date."
    end

    test "incident queue opens with unresolved cases and allows all statuses" do
      second = NoShowIncident.create!(ride_post: @ride, user: @driver, status: :dismissed, occurred_at: 2.hours.ago)
      sign_in_as(@admin)
      get admin_root_path
      assert_select "#no_show_incident_#{@incident.id}"
      assert_select "#no_show_incident_#{second.id}", count: 0

      get admin_no_show_incidents_path, params: { status: "all", ride_post_id: @ride.id,
        from: 1.day.ago.to_date.iso8601, to: Date.current.iso8601 }
      assert_select "#no_show_incident_#{@incident.id}"
      assert_select "#no_show_incident_#{second.id}"
    end

    test "case displays only its own reports along with historical booking context" do
      unrelated = TripReview.create!(ride_post: @ride, reporter: @passenger, reported_user: @driver,
        outcome: :completed, notes: "Unrelated participant evidence.")
      bookings(:one).update_columns(status: Booking.statuses[:canceled], canceled_at: 1.hour.ago,
        canceled_by_id: @passenger.id)
      sign_in_as(@admin)
      get admin_no_show_incident_path(@incident)
      assert_response :success
      assert_select "a[href=?]", admin_trip_review_path(@review)
      assert_select "a[href=?]", admin_trip_review_path(unrelated), count: 0
      assert_select "h2", text: "Booking history"
      assert_select "dt", text: "Canceled by"
      assert_select "p", text: /Passenger missed the agreed pickup/
    end

    test "decision uses logged in reviewer and a retry does not duplicate history or notifications" do
      sign_in_as(@admin)
      attributes = decision_params
      attributes[:no_show_incident][:reviewer_id] = @driver.id
      assert_difference [ "NoShowIncidentDecision.count", "Notification.count" ], 1 do
        patch admin_no_show_incident_path(@incident), params: attributes
      end
      assert_redirected_to admin_no_show_incident_path(@incident)
      assert_equal @admin.id, @incident.reload.reviewer_id
      assert @incident.upheld?
      assert_equal "[FILTERED]", request.filtered_parameters.dig("no_show_incident", "reason")
      follow_redirect!
      assert_select "[role='status']", text: /Decision saved\./

      assert_no_difference [ "NoShowIncidentDecision.count", "Notification.count" ] do
        patch admin_no_show_incident_path(@incident), params: attributes
      end
      assert_redirected_to admin_no_show_incident_path(@incident)
    end

    test "decision requires reason and version and cannot reset a case to pending" do
      sign_in_as(@admin)
      [ { reason: " " }, { lock_version: nil }, { status: "pending" } ].each do |override|
        assert_no_difference [ "NoShowIncidentDecision.count", "Notification.count" ] do
          patch admin_no_show_incident_path(@incident), params: decision_params(**override)
        end
        assert_response :unprocessable_content
        assert @incident.reload.pending?
      end
    end

    test "stale decisions render conflict with refreshed version and preserve entered reason" do
      sign_in_as(@admin)
      attributes = decision_params(status: "dismissed", reason: "My unsaved reasoning")
      NoShowIncidents::AdjudicateService.call(@incident, reviewer: @admin, status: :upheld,
        reason: "Earlier decision", expected_version: @incident.lock_version)
      assert_no_difference [ "NoShowIncidentDecision.count", "Notification.count" ] do
        patch admin_no_show_incident_path(@incident), params: attributes
      end
      assert_response :conflict
      assert_select "textarea[name='no_show_incident[reason]']", text: "My unsaved reasoning"
      assert_select "input[name='no_show_incident[lock_version]'][value=?]", @incident.reload.lock_version.to_s
      assert_select "#decision-history", text: /Earlier decision/
      assert @incident.upheld?
    end

    test "trip participants with admin rights can read the case but cannot decide it" do
      User.where(id: @driver.id).update_all(admin: true)
      sign_in_as(@driver)
      get admin_no_show_incident_path(@incident)
      assert_response :success
      assert_select "form[action=?]", admin_no_show_incident_path(@incident), count: 0
      assert_select "p", text: "Another administrator must review this case"
      patch admin_no_show_incident_path(@incident), params: decision_params
      assert_response :unprocessable_content
      assert @incident.reload.pending?
      assert_equal 0, @incident.decisions.count
    end

    private

    def decision_params(status: "upheld", reason: "Reviewed the pickup reports.", lock_version: @incident.lock_version)
      { no_show_incident: { status: status, reason: reason, lock_version: lock_version } }
    end
  end
end
