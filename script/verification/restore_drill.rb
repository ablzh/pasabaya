# frozen_string_literal: true

require_relative "support"
require "fileutils"

Verification.run do |directory|
  require "active_support/testing/time_helpers"
  extend ActiveSupport::Testing::TimeHelpers
  snapshot_time = 2.days.ago.change(usec: 0)
  driver = passenger = ride = expired_ride = nil
  snapshot_path = File.join(directory, "snapshot.sqlite3")
  travel_to(snapshot_time) do
    driver = Verification.user("driver")
    passenger = Verification.user("passenger")
    origin = Location.create!(name: "Synthetic origin", location_type: :city)
    destination = Location.create!(name: "Synthetic destination", location_type: :city)
    ride = RidePost.create!(user: driver, origin: origin, destination: destination, seats: 2, status: :active, departure_time: 6.hours.from_now)
    booking = Bookings::CreateService.call(ride_post: ride, passenger: passenger)
    Bookings::AcceptService.call(booking, actor: driver)
    ride.chat_messages.create!(user: passenger, body: "Synthetic deleted account message")
    ride.chat_messages.create!(user: driver, body: "Synthetic retained message")
    passenger.sessions.create!
    expired_ride = RidePost.create!(user: driver, origin: origin, destination: destination, seats: 2, status: :draft)
    expired_ride.update_columns(status: RidePost.statuses[:completed], departure_time: 35.days.ago, departure_date: 35.days.ago.to_date)
    # Seed a historical conversation that has passed its retention deadline.
    ChatMessage.insert_all!([ { ride_post_id: expired_ride.id, user_id: driver.id, body: "Synthetic expired message", created_at: 35.days.ago, updated_at: 35.days.ago } ])
    ActiveRecord::Base.connection.execute("VACUUM INTO #{ActiveRecord::Base.connection.quote(snapshot_path)}")
  end
  snapshot_created_at = Time.current
  Verification.check(Users::AnonymizeService.call(passenger), "Initial deletion failed")
  registry_before_restore = File.read(Users::DeletionRegistry.path)

  started = Verification.clock
  database_path = ActiveRecord::Base.connection_db_config.database
  ActiveRecord::Base.connection_pool.disconnect!
  FileUtils.cp(snapshot_path, database_path)
  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: database_path)
  Verification.check(!passenger.reload.deleted? && passenger.sessions.exists?, "Snapshot must resurrect the pre-deletion account and session")
  Verification.check(ChatMessage.where(ride_post_id: expired_ride.id).exists?, "Snapshot must include expired content before reconciliation")
  Verification.check(File.read(Users::DeletionRegistry.path) == registry_before_restore, "Restore replaced the current journal")

  Rails.application.load_tasks
  Rake::Task["db:restore:finish"].invoke
  duration = Verification.clock - started
  Verification.check(passenger.reload.deleted?, "Deleted account was not reconciled")
  Verification.check(!User.authenticate_by(email_address: "passenger@example.test", password: "synthetic-password"), "Deleted credentials still work")
  Verification.check(!passenger.sessions.exists? && !passenger.chat_messages.exists?, "Deleted session or content survived")
  Verification.check(!ChatMessage.where(ride_post_id: expired_ride.id).exists?, "Expired chat survived")
  Verification.check(ride.chat_messages.where(user_id: driver.id).count == 1, "Unexpired survivor history was lost")
  Verification.check(passenger.bookings.where.not(accepted_at: nil).count == 1, "Historical acceptance was lost")

  browser = ActionDispatch::Integration::Session.new(Rails.application)
  browser.post("/session", params: { email_address: driver.email_address, password: "synthetic-password" })
  Verification.check(browser.response.redirect? && URI.parse(browser.response.location).path == "/", "Survivor sign in failed")
  browser.get(Rails.application.routes.url_helpers.ride_post_path(expired_ride, tab: "chat"))
  Verification.check(browser.response.redirect? && URI.parse(browser.response.location).path == Rails.application.routes.url_helpers.ride_post_path(expired_ride), "Expired chat request was not redirected to trip details")
  browser.follow_redirect!
  Verification.check(browser.response.status == 200 && !browser.response.body.include?("trip-chat-pane") && !browser.response.body.include?("Synthetic expired message"), "Expired chat remains available over HTTP")

  puts JSON.generate(workflow: "restore_drill", recorded_at: Time.current.utc.iso8601, environment: Verification.environment,
    data: "synthetic only", simulated_backup_age_seconds: (Time.current - snapshot_time).round(2),
    backup_file_age_seconds: (Time.current - snapshot_created_at).round(3), restore_and_reconcile_seconds: duration.round(3),
    checks: { journal_preserved: true, account_anonymized: true, credentials_rejected: true, sessions_removed: true,
      deleted_messages_removed: true, expired_chat_removed: true, expired_chat_http_denied: true,
      unexpired_history_retained: true, historical_acceptance_retained: true })
end
