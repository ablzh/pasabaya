# Signed stream names identify streams, but do not replace authorization.
# All application subscriptions use NotificationsChannel or RideChatChannel.
Rails.application.config.to_prepare do
  Turbo::StreamsChannel.class_eval do
    def subscribed
      reject
    end
  end
end
