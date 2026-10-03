module RidePostsHelper
  def ride_availability_text(ride)
    return "Unpublished — edit to publish" if ride.draft?
    return "Canceled — bookings closed" if ride.canceled?
    return "Past — bookings closed" if ride.completed?
    return "Departed — bookings closed" if ride.departure_time.present? && ride.departure_time <= Time.current
    return ride.fulfilled? ? "Request fulfilled" : "Looking for a driver" if ride.requesting?
    return "Fully booked" if ride.full?
    return "Accepting requests" if ride.bookable?

    "Bookings closed"
  end
end
