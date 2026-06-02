class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :ride_posts, dependent: :destroy

  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_limit: [100, 100]
  end

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # Ensure the Facebook link is always provided
  validates :facebook_profile_url, presence: true

  # A simple regex to ensure it looks vaguely like a URL
  validates :facebook_profile_url, format: { with: URI::DEFAULT_PARSER.make_regexp }

  attr_readonly :admin

  def initials
    "#{first_name&.first}#{last_name&.first}".upcase
  end

end
