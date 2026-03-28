class Subscriber < ApplicationRecord
  attr_accessor :terms_accepted

  before_validation :normalize_email

  validates :terms_accepted, acceptance: true
  validates :name, presence: true

  validates :email,
            presence: true,
            format: { with: URI::MailTo::EMAIL_REGEXP },
            uniqueness: { case_sensitive: false }

  private

  def normalize_email
    self.email = email.downcase.strip if email.present?
  end
end
