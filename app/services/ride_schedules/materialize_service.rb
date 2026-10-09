module RideSchedules
  class MaterializeService
    def self.call(schedule)
      schedule.with_lock do
        return unless schedule.active?
        ActiveRecord::Associations::Preloader.new(records: [ schedule ], associations: [ :user, :origin, :destination, :community ]).call
        unless schedule.driver_eligible?
          TransitionService.call(schedule: schedule, actor: schedule.user, action: :pause)
          return
        end

        dates = schedule.generation_dates
        existing = schedule.ride_posts.includes(:bookings, :user, :origin, :destination).where("departure_date >= ?", Date.current).index_by(&:schedule_date)
        cancelled_ids = []
        existing.each_value do |ride|
          next if ride.canceled? || ride.completed? || ride.booking_cutoff_at <= Time.current || ride.requests_closed_at.present? || ride.bookings.any? { |booking| booking.active? }

          if dates.include?(ride.schedule_date)
            # Each occurrence owns inventory; refreshing must never reset it.
            changes = schedule.ride_attributes(ride.schedule_date).except(:status, :remaining_seats)
            ride.assign_attributes(changes.merge(user: schedule.user, origin: schedule.origin, destination: schedule.destination, community: schedule.community))
            if ride.booking_cutoff_at <= Time.current
              cancelled_ids << ride.id
              next
            end
            # The driver has been refreshed within this primary write transaction.
            ride.save!(context: [ :update, :schedule_generation ]) if ride.changed?
          elsif !schedule.weekday_ids.include?(ride.schedule_date.wday) || (schedule.end_date && ride.schedule_date > schedule.end_date)
            cancelled_ids << ride.id
          end
        end
        RidePosts::CancelService.call_many(RidePost.where(id: cancelled_ids), actor: schedule.user) if cancelled_ids.any?

        dates.each do |date|
          next if existing.key?(date)

          attributes = schedule.ride_attributes(date)
          candidate = schedule.ride_posts.build(attributes.merge(schedule_date: date, user: schedule.user, origin: schedule.origin, destination: schedule.destination, community: schedule.community))
          next if candidate.booking_cutoff_at <= Time.current

          candidate.save!(context: [ :create, :schedule_generation ])
        end
      end
    end
  end
end
