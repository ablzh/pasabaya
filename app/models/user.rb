class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :ride_posts, dependent: :destroy

  has_one_attached :avatar do |attachable|
    attachable.variant :thumb,
                       resize_to_limit: [160, 160],
                       format: :webp,
                       saver: { strip: true },
                       convert: "webp"
  end

  validate :acceptable_avatar

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # Ensure names are always provided and not blank
  validates :first_name, presence: true
  validates :last_name, presence: true

  # Ensure the Facebook link is always provided
  validates :facebook_profile_url, presence: true

  # A simple regex to ensure it looks vaguely like a URL
  validates :facebook_profile_url, format: { with: URI::DEFAULT_PARSER.make_regexp }

  attr_readonly :admin

  def initials
    "#{first_name&.first}#{last_name&.first}".upcase
  end

  private

  def acceptable_avatar
    return unless avatar.attached?

    # 1. Enforce size limit (e.g., max 5MB to save server storage)
    if avatar.blob.byte_size > 5.megabytes
      errors.add(:avatar, "is too large (must be under 5MB)")
    end

    # 2. Enforce file types (images only)
    acceptable_types = ["image/jpeg", "image/png", "image/webp"]
    unless acceptable_types.include?(avatar.content_type)
      errors.add(:avatar, "must be a JPEG, PNG, or WEBP image")
    end
  end

end
