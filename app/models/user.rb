class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  attr_readonly :admin

  def initials
    "#{first_name&.first}#{last_name&.first}".upcase
  end

end
