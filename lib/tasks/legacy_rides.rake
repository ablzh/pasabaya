namespace :legacy_rides do
  desc "Preview the reviewed October 22 ride import (EXECUTE=1 applies it)"
  task import: :environment do
    require Rails.root.join("script/legacy_rides_upgrade")
    LegacyRidesUpgrade.new.import(dry_run: ENV["EXECUTE"] != "1")
  end

  desc "Preview the snapshot's personalized and general update emails after deployment (EXECUTE=1 sends them)"
  task notify: :environment do
    require Rails.root.join("script/legacy_rides_upgrade")
    LegacyRidesUpgrade.new.notify(dry_run: ENV["EXECUTE"] != "1")
  end
end
