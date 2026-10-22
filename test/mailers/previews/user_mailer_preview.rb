# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  def platform_update
    user = User.where(deleted_at: nil, banned_at: nil).first
    UserMailer.with(user_id: user&.id).platform_update
  end

  def ride_upgrade
    # Preview the transferred rides after running the legacy ride upgrade.
    user = User.joins(:ride_schedules).where(deleted_at: nil, banned_at: nil).first
    UserMailer.with(user_id: user&.id, schedule_ids: user&.ride_schedules&.ids || []).ride_upgrade
  end

  def dated_ride_upgrade
    # The reviewed one-time offers share an owner; previews never send mail.
    rides = RidePost.where(id: [ 18, 19 ])
    user = rides.first&.user
    UserMailer.with(user_id: user&.id, ride_ids: rides.where(user_id: user&.id).ids).ride_upgrade
  end

  def welcome
    # Grab the first User from the database, or build a dummy one if your DB is empty
    user = User.first || User.new(
      first_name: "Juan",
      last_name: "Dela Cruz",
      email_address: "juan@example.com"
    )

    UserMailer.welcome(user)
  end
end
