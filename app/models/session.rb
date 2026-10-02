class Session < ApplicationRecord
  belongs_to :user

  after_destroy_commit :disconnect_live_connections

  private

  def disconnect_live_connections
    ActionCable.server.remote_connections.where(current_user: user, current_session: self).disconnect(reconnect: false)
  end
end
