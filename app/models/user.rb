class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :ride_posts, dependent: :destroy
  has_many :bookings, foreign_key: :passenger_id, dependent: :destroy, inverse_of: :passenger
  has_many :canceled_bookings, class_name: "Booking", foreign_key: :canceled_by_id, dependent: :nullify, inverse_of: :canceled_by
  has_many :received_notifications, class_name: "Notification", foreign_key: :recipient_id, dependent: :destroy, inverse_of: :recipient
  has_many :acted_notifications, class_name: "Notification", foreign_key: :actor_id, dependent: :nullify, inverse_of: :actor
  has_many :chat_messages, dependent: :destroy

  enum :gender, { unspecified: 0, female: 1, male: 2, non_binary: 3 }, default: :unspecified

  has_one_attached :avatar do |attachable|
    attachable.variant :thumb,
                       resize_to_limit: [ 160, 160 ],
                       format: :webp,
                       saver: { strip: true },
                       convert: "webp"
  end

  validate :acceptable_avatar

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # Ensure email is present, unique, and validly formatted
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  # Ensure names are always provided and not blank
  validates :first_name, presence: true
  validates :last_name, presence: true

  # Ensure the Facebook link is always provided
  validates :facebook_profile_url, presence: true

  # A simple regex to ensure it looks vaguely like a URL
  validates :facebook_profile_url, format: { with: URI::DEFAULT_PARSER.make_regexp }

  attr_readonly :admin

  validates :gender, presence: true

  def initials
    "#{first_name&.first}#{last_name&.first}".upcase
  end

  def booking_frozen?
    booking_freeze_until.present? && booking_freeze_until > Time.current
  end

  def eligible_for_booking?
    banned_at.blank? && !booking_frozen?
  end

  def eligible_for_offering?
    banned_at.blank? && !booking_frozen?
  end


  # UPDATE EMAIL

  # 1. Validations for new email (optional/format check)
  validates :unconfirmed_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validate :unconfirmed_email_uniqueness

  # 3. Token generator for email confirmation (expires in 7 days)
  generates_token_for :email_confirmation, expires_in: 7.days do
    unconfirmed_email
  end

  # 4. Confirmation method
  def confirm_email
    update(email_address: unconfirmed_email, unconfirmed_email: nil)
  end


  private

  def acceptable_avatar
    return unless avatar.attached?

    # 1. Enforce size limit (e.g., max 5MB to save server storage)
    if avatar.blob.byte_size > 5.megabytes
      errors.add(:avatar, "is too large (must be under 5MB)")
    end

    # 2. Enforce file types (images only)
    acceptable_types = [ "image/jpeg", "image/png", "image/webp" ]
    unless acceptable_types.include?(avatar.content_type)
      errors.add(:avatar, "must be a JPEG, PNG, or WEBP image")
    end
  end

  def unconfirmed_email_uniqueness
    if unconfirmed_email.present? && User.exists?(email_address: unconfirmed_email)
      errors.add(:unconfirmed_email, "is already taken")
    end
  end
end
