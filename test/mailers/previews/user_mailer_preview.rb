# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  def community_survey
    user = User.where(deleted_at: nil, banned_at: nil).first || User.new(
      first_name: "Juan",
      last_name: "Dela Cruz",
      email_address: "juan@example.com"
    )

    if user.persisted?
      UserMailer.with(user_id: user.id).community_survey
    else
      UserMailer.with(user: user).community_survey
    end
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
