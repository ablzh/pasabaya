# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  def welcome_email
    subscriber = Subscriber.first || Subscriber.new(name: "Test User", email: "example@example.com")
    UserMailer.welcome_email(subscriber)
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
