# Preview all emails at http://localhost:3000/rails/mailers/passwords_mailer
class PasswordsMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/passwords_mailer/reset
  def reset
    user = User.take || User.new(email_address: "test@example.com").tap do |u|
      def u.password_reset_token; "dummy-token-for-preview"; end
      def u.password_reset_token_expires_in; 15.minutes; end
    end
    PasswordsMailer.reset(user)
  end
end
