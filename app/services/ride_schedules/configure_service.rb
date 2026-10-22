module RideSchedules
  class ConfigureService
    class Error < StandardError; end

    def self.call(schedule:, actor:, attributes:)
      RideSchedule.transaction do
        schedule.lock! if schedule.persisted?
        raise Error, "Only the driver can edit this schedule" unless schedule.user_id == actor.id
        raise Error, "An ended schedule cannot be changed" if schedule.archived?

        schedule.assign_attributes(attributes)
        raise Error, "The schedule must belong to its driver" unless schedule.user_id == actor.id
        if schedule.source_ride_post_id.present?
          source = actor.ride_posts.lock.find(schedule.source_ride_post_id)
          raise Error, "Only a private draft without bookings can be converted" unless source.draft? && source.bookings.empty?
        end
        schedule.save!
        MaterializeService.call(schedule)
        schedule
      end
    end
  end
end
