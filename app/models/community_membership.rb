class CommunityMembership < ApplicationRecord
  belongs_to :user
  belongs_to :community

  normalizes :institutional_email, with: ->(e) { e.to_s.strip.downcase }

  before_validation :refresh_user, on: :create
  validate :user_must_not_be_deleted, on: :create

  validates :user_id, uniqueness: { scope: :community_id, message: "is already a member of this community" }
  validates :institutional_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP },
                                  uniqueness: {
                                    conditions: -> { where("verified_at IS NOT NULL AND revoked_at IS NULL") },
                                    message: "is already registered and verified by another user"
                                  }
  validate :email_domain_matches_community

  generates_token_for :verification, expires_in: 24.hours do
    [ institutional_email, verified_at, revoked_at, updated_at ]
  end

  scope :active_verified, -> {
    where.not(verified_at: nil)
         .where(revoked_at: nil)
         .where("expires_at IS NULL OR expires_at > ?", Time.current)
  }

  scope :expired, -> {
    where.not(expires_at: nil)
         .where("expires_at <= ?", Time.current)
         .where(revoked_at: nil)
  }

  def self.revoke_expired!
    expired.find_each(&:revoke!)
  end

  def verified?
    verified_at.present? && revoked_at.blank? && (expires_at.blank? || expires_at > Time.current)
  end

  def pending_verification?
    verified_at.blank? && revoked_at.blank?
  end

  def verify!
    transaction do
      if revoked_at.present?
        errors.add(:base, :revoked_membership, message: "Revoked membership cannot be verified directly. Please request a new verification link.")
        raise ActiveRecord::RecordInvalid.new(self)
      end

      if CommunityMembership.active_verified.where(institutional_email: institutional_email).where.not(id: id).exists?
        errors.add(:institutional_email, :already_verified, message: "is already verified by another account")
        raise ActiveRecord::RecordInvalid.new(self)
      end

      update!(verified_at: Time.current, revoked_at: nil, expires_at: 1.year.from_now)
    end
  end

  def revoke!
    transaction do
      update!(revoked_at: Time.current)

      # 1. Cancel upcoming passenger bookings in this community
      affected_bookings = Booking.joins(:ride_post)
                                 .where(passenger_id: user_id, status: [ :pending, :accepted ])
                                 .where(ride_posts: { visibility: :hub_only, community_id: community_id })
                                 .merge(RidePost.upcoming)

      affected_bookings.find_each do |booking|
        Bookings::CancelService.new(booking, actor: user).call
      end

      # 2. Cancel driver's upcoming hub-only rides (both active and fulfilled) for this community
      user.ride_posts.hub_only.where(community_id: community_id)
                             .upcoming
                             .where(status: [ :active, :fulfilled ])
                             .find_each do |ride|
        RidePosts::CancelService.new(ride, actor: user).call
      end
    end
  end

  private

  def refresh_user
    self.user = User.lock.find_by(id: user_id) if user_id
  end

  def user_must_not_be_deleted
    errors.add(:user, :deleted_account, message: "is not eligible to join communities") if user&.deleted?
  end

  def email_domain_matches_community
    return if institutional_email.blank? || community.blank?

    domain_part = institutional_email.split("@").last.to_s.downcase
    if domain_part != community.domain.downcase
      errors.add(:institutional_email, :wrong_domain, message: "must match the community domain (@#{community.domain})")
    end
  end
end
