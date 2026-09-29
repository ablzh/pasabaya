class Notification < ApplicationRecord
  belongs_to :recipient, class_name: "User"
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :notifiable, polymorphic: true

  enum :delivery_status, { pending: 0, delivered: 1, failed: 2 }, default: :pending

  validates :event_name, presence: true
  validates :delivery_key, presence: true, uniqueness: true
  validates :delivery_status, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  def mark_as_read!
    update!(read_at: Time.current) unless read_at?
  end

  def read?
    read_at.present?
  end
end
