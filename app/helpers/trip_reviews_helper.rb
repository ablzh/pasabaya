module TripReviewsHelper
  def trip_review_outcome_options(review, ride)
    driver = review.reported_user_id == ride.user_id
    [
      [ "Ride completed smoothly", "completed" ],
      [ "Passenger did not show up (No-show)", "passenger_no_show", { disabled: driver, hidden: driver } ],
      [ "Driver did not show up (No-show)", "driver_no_show", { disabled: !driver, hidden: !driver } ],
      [ "Canceled last minute", "canceled_last_minute" ],
      [ "Other issue / dispute", "other_issue" ]
    ]
  end
end
