module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :current_session

    def connect
      set_current_user || reject_unauthorized_connection
    end

    private
      def set_current_user
        if (session = Session.includes(:user).find_by(id: cookies.signed[:session_id])) && session.user.banned_at.blank? && !session.user.deleted?
          self.current_user = session.user
          self.current_session = session
        end
      end
  end
end
