class Session < ApplicationRecord
  belongs_to :user

  before_create :reject_deleted_account

  after_destroy_commit :disconnect_live_connections

  private

  def reject_deleted_account
    if User.lock.find(user_id).deleted?
      errors.add(:base, "This account has been deleted.")
      throw :abort
    end
  end

  def disconnect_live_connections
    ActionCable.server.remote_connections.where(current_user: user, current_session: self).disconnect(reconnect: false)
  end
end
