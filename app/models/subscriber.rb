class Subscriber < ApplicationRecord
  attr_accessor :terms_accepted
  validates :terms_accepted, acceptance: true

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
end
