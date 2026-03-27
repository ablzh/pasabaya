# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  def welcome_email
    subscriber = Subscriber.first || Subscriber.new(name: "Test User", email: "example@example.com")
    UserMailer.welcome_email(subscriber)
  end
end
