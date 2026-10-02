module ApplicationCable
  class Channel < ActionCable::Channel::Base
    private

    def active_session?
      current_session.present? && Session.exists?(id: current_session.id, user_id: current_user&.id)
    end
  end
end
