# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  def welcome_email
    UserMailer.welcome_email(Subscriber.new(name: "Тестовый Юзер", email: "example@example.com"))
  end
end