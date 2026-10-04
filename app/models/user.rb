class User < ApplicationRecord
  REGISTRATION_POLICY_VERSION = "2026-10-03".freeze

  attr_accessor :registration_acceptance

  validate :registration_attestation, on: :registration

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :ride_posts, dependent: :destroy
  has_many :bookings, foreign_key: :passenger_id, dependent: :destroy, inverse_of: :passenger
  has_many :canceled_bookings, class_name: "Booking", foreign_key: :canceled_by_id, dependent: :nullify, inverse_of: :canceled_by
  has_many :received_notifications, class_name: "Notification", foreign_key: :recipient_id, dependent: :destroy, inverse_of: :recipient
  has_many :acted_notifications, class_name: "Notification", foreign_key: :actor_id, dependent: :nullify, inverse_of: :actor
  has_many :chat_messages, dependent: :destroy

  def mark_all_notifications_as_read!
    snapshot_id = received_notifications.maximum(:id)
    return unless snapshot_id

    received_notifications.unread.where("id <= ?", snapshot_id).update_all(read_at: Time.current, updated_at: Time.current)
    Turbo::StreamsChannel.broadcast_update_to(
      [ self, :notifications ], target: "notifications_list",
      partial: "notifications/list", locals: { notifications: received_notifications.includes(:actor).recent.limit(50) }
    )
    Turbo::StreamsChannel.broadcast_update_to(
      [ self, :notifications ], targets: "[data-notification-count]",
      partial: "notifications/count", locals: { count: received_notifications.unread.count }
    )
  end
  has_many :community_memberships, dependent: :destroy
  has_many :communities, through: :community_memberships
  has_many :reported_trip_reviews, class_name: "TripReview", foreign_key: :reporter_id, dependent: :restrict_with_error, inverse_of: :reporter
  has_many :received_trip_reviews, class_name: "TripReview", foreign_key: :reported_user_id, dependent: :restrict_with_error, inverse_of: :reported_user
  has_many :no_show_incidents, dependent: :restrict_with_error
  has_many :adjudicated_incidents, class_name: "NoShowIncident", foreign_key: :reviewer_id, dependent: :nullify, inverse_of: :reviewer

  before_destroy :cancel_active_commitments, prepend: true
  before_update :reject_updates_after_deletion
  after_update_commit :withdraw_ineligible_participation, if: :saved_change_to_gender?

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
  validate :reject_reserved_internal_domains, on: :create

  # Ensure names are always provided and not blank
  validates :first_name, presence: true
  validates :last_name, presence: true

  normalizes :facebook_profile_url, with: ->(url) { url.to_s.strip.presence }

  validate :acceptable_facebook_profile_url, if: -> { new_record? || will_save_change_to_facebook_profile_url? }

  attr_readonly :admin

  validates :gender, presence: true

  def deleted?
    deleted_at.present?
  end

  def initials
    "#{first_name&.first}#{last_name&.first}".upcase
  end

  def safe_facebook_profile_url?
    return false if facebook_profile_url.blank?

    uri = URI.parse(facebook_profile_url.to_s)
    uri.is_a?(URI::HTTPS) && %w[facebook.com www.facebook.com m.facebook.com].include?(uri.host&.downcase) &&
      uri.userinfo.nil? && uri.port == 443 && uri.path.present? && uri.path != "/"
  rescue URI::InvalidURIError
    false
  end

  def booking_frozen?
    booking_freeze_until.present? && booking_freeze_until > Time.current
  end

  def eligible_for_booking?
    banned_at.blank? && !booking_frozen? && !deleted?
  end

  def eligible_for_offering?
    banned_at.blank? && !booking_frozen? && !deleted?
  end

  def verified_community_memberships
    community_memberships.active_verified
  end

  def verified_communities
    communities.merge(CommunityMembership.active_verified)
  end

  def verified_community_ids
    verified_community_memberships.pluck(:community_id)
  end

  def verified_member_of?(community_or_id)
    comm_id = community_or_id.is_a?(Community) ? community_or_id.id : community_or_id
    verified_community_memberships.where(community_id: comm_id).exists?
  end

  def recent_upheld_incidents_count
    no_show_incidents.upheld.where("occurred_at >= ?", 60.days.ago).count
  end

  def reliability_warning?
    recent_upheld_incidents_count >= 2
  end

  def active_trips_count
    driver_count = ride_posts.where(status: [ :active, :fulfilled ]).upcoming.count
    passenger_count = bookings.accepted.joins(:ride_post).where(ride_posts: { status: [ :active, :fulfilled ] }).merge(RidePost.upcoming).count
    driver_count + passenger_count
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
    return false if deleted? || unconfirmed_email.blank?

    update(email_address: unconfirmed_email, unconfirmed_email: nil)
  end


  private

  def registration_attestation
    unless registration_acceptance == "1"
      errors.add(:base, "You must be at least 18 years old and agree to the Terms of Service and Privacy Policy to register.")
    end
  end

  def reject_updates_after_deletion
    if User.lock.find(id).deleted?
      errors.add(:base, "This account has been deleted.")
      throw :abort
    end
  end

  def reject_reserved_internal_domains
    return if email_address.blank?

    if email_address.downcase.end_with?("@deleted.pasabaya.app")
      errors.add(:email_address, "is reserved and cannot be registered")
    end
  end

  def acceptable_facebook_profile_url
    if facebook_profile_url.present? && !safe_facebook_profile_url?
      errors.add(:facebook_profile_url, "must be an HTTPS Facebook profile URL")
    end
  end

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

  def cancel_active_commitments
    bookings.active.find_each do |b|
      Bookings::CancelService.call(b, actor: self)
    end

    ride_posts.where(status: [ :active, :fulfilled ]).find_each do |ride|
      RidePosts::CancelService.call(ride, actor: self)
    end
  end

  def withdraw_ineligible_participation
    return if female?

    # Cancel passenger bookings on ladies-only rides
    bookings.joins(:ride_post)
            .where(status: [ :pending, :accepted ])
            .where(ride_posts: { ladies_only: true })
            .merge(RidePost.upcoming)
            .find_each do |booking|
      Bookings::CancelService.call(booking, actor: self)
    end

    # Cancel driver offers for ladies-only rides
    ride_posts.where(ladies_only: true)
              .upcoming
              .where(status: [ :active, :fulfilled ])
              .find_each do |ride|
      RidePosts::CancelService.call(ride, actor: self)
    end
  end
end
