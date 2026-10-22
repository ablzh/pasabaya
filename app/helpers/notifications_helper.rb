module NotificationsHelper
  def notification_route_label(ride)
    ActiveRecord::Associations::Preloader.new(records: [ ride ], associations: [ :origin, :destination ]).call
    "#{ride.origin&.name} to #{ride.destination&.name}"
  end
end
