class HardenRideScheduleConstraints < ActiveRecord::Migration[8.1]
  def change
    remove_index :ride_posts, :ride_schedule_id
    add_check_constraint :ride_posts, "ride_schedule_id IS NULL OR departure_date IS NOT NULL", name: "check_scheduled_departures_have_date"
    add_check_constraint :ride_schedules, "visibility != 1 OR community_id IS NOT NULL", name: "check_ride_schedules_hub_requires_community"
    add_index :ride_schedules, [ :status, :end_date ]
  end
end
