class RideScheduleRefreshJob < ApplicationJob
  queue_as :default

  def perform
    RideSchedule.active.find_each { |schedule| RideSchedules::MaterializeService.call(schedule) }
  end
end
