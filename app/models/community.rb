class Community < ApplicationRecord
  has_many :community_memberships, dependent: :destroy
  has_many :users, through: :community_memberships
  has_many :ride_posts, dependent: :nullify
  has_many :route_subscriptions, dependent: :nullify

  enum :hub_type, { company: 0, campus: 1, other: 2 }, default: :company

  normalizes :domain, with: ->(d) { d.to_s.strip.downcase.delete_prefix("@") }
  normalizes :slug, with: ->(s) { s.to_s.strip.downcase }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :domain, presence: true, uniqueness: true
  validates :hub_type, presence: true

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  def self.cleanup_disposable_local_hubs!
    return unless Rails.env.development? || Rails.env.test?

    transaction do
      where.not(domain: "up.edu.ph").find_each do |community|
        community.ride_posts.each(&:destroy!)
        community.route_subscriptions.destroy_all
        community.community_memberships.destroy_all
        community.destroy!
      end
    end
  end

  def to_param
    slug
  end

  def verified_members_count
    community_memberships.active_verified.count
  end

  private

  def generate_slug
    self.slug = name.parameterize
  end
end
