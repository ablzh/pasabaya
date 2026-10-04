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
      current_user.reload
      transmit data if route_alerts_available?(data) && chat_previews_available?(data)
    else
      stop_all_streams
      reject
    end
  end
  private

  def chat_previews_available?(data)
    ids = Nokogiri::HTML.fragment(data.to_s).css("[data-ride-id]").filter_map { |node| node["data-ride-id"].presence }
    return true if ids.empty?

    rides = RidePost.where(id: ids)
    rides.size == ids.uniq.size && rides.all? { |ride| ride.user_authorized_for_chat?(current_user) }
  end

  def route_alerts_available?(data)
    ids = Nokogiri::HTML.fragment(data.to_s).css("[data-route-alert-id]").filter_map { |node| node["data-route-alert-id"].presence }
    return true if ids.empty?

    alerts = current_user.received_notifications.where(id: ids)
    alerts.size == ids.uniq.size && alerts.all?(&:route_alert_available?)
  end
end
