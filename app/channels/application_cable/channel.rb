module ApplicationCable
  class Channel < ActionCable::Channel::Base
    private

    def active_session?
      current_session.present? && Session.joins(:user).exists?(id: current_session.id, user_id: current_user&.id, users: { deleted_at: nil, banned_at: nil })
    end
  end
end
