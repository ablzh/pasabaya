module RideSchedules
  class TransitionService
    class Error < StandardError; end

    def self.call(schedule:, actor:, action:)
      schedule.with_lock do
        raise Error, "Only the driver can manage this schedule" unless schedule.user_id == actor.id
        raise Error, "An ended schedule cannot be resumed" if schedule.archived? && action != :cancel_future

        case action
        when :pause
          raise Error, "Publish the schedule before pausing it" if schedule.draft?
          schedule.update!(status: :paused)
          Bookings::ExpireService.call(schedule)
        when :resume
          raise Error, "Only a paused schedule can be resumed" unless schedule.paused?
          schedule.update!(status: :active)
          MaterializeService.call(schedule)
        when :cancel_future
          raise Error, "A private draft has no departures to cancel" if schedule.draft?
          schedule.update!(status: :archived)
          RidePosts::CancelService.call_many(schedule.ride_posts.upcoming.where(status: [ :active, :fulfilled ]), actor: actor)
        else
          raise Error, "Unknown schedule action"
        end
        schedule
      end
    end
  end
end
