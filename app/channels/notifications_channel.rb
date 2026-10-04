class NotificationsChannel < ApplicationCable::Channel
  extend Turbo::Streams::Broadcasts, Turbo::Streams::StreamName
  include Turbo::Streams::StreamName::ClassMethods

  def subscribed
    stream_name = verified_stream_name_from_params
    allowed_streams = [
      self.class.send(:stream_name_from, [ current_user, :notifications ]),
      self.class.send(:stream_name_from, [ current_user, :chats ])
    ]
    if active_session? && allowed_streams.include?(stream_name)
      stream_from stream_name, coder: ActiveSupport::JSON do |data|
        deliver_or_reject(data)
      end
    else
      reject
    end
  end

  def deliver_or_reject(data)
    if active_session? && User.where(id: current_user.id, banned_at: nil).exists?
      transmit data
    else
      stop_all_streams
      reject
    end
  end
end
