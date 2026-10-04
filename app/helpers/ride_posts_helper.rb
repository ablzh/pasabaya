module RidePostsHelper
  def ride_availability_text(ride)
    return "Unpublished — edit to publish" if ride.draft?
    return "Canceled — bookings closed" if ride.canceled?
    return "Past — bookings closed" if ride.completed?
    return "Departed — bookings closed" if ride.booking_cutoff_at.present? && ride.booking_cutoff_at <= Time.current
    return "Fully booked" if ride.full?
    return "Accepting requests" if ride.bookable?

    "Bookings closed"
  end
end
