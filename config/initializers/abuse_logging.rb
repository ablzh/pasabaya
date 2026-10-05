# Only server-defined operation names belong in abuse metrics. Notification
# payloads also contain request identifiers and form data; never serialize them.
protected_actions = {
  "registrations" => "create",
  "sessions" => "create",
  "passwords" => "create",
  "community_memberships" => "create",
  "settings/emails" => "update",
  "ride_posts" => "create",
  "bookings" => "create",
  "route_subscriptions" => "create",
  "trip_reviews" => "create",
  "chat_messages" => "create"
}.freeze
controller_limiters = %w[default ip account recipient-minute recipient-hour].freeze

%w[rate_limit.action_controller invisible_captcha.spam_detected throttle.rack_attack].each do |event_name|
  ActiveSupport::Notifications.subscribe(event_name) do |event|
    data = { event: event.name }

    if event.name == "throttle.rack_attack"
      limiter = event.payload[:request]&.env&.fetch("rack.attack.matched", nil)
      data[:limiter] = limiter if Rack::Attack.throttles.key?(limiter)
    else
      parameters = if event.name == "rate_limit.action_controller"
        event.payload[:request]&.path_parameters || {}
      else
        event.payload
      end
      controller = parameters[:controller]
      action = parameters[:action]
      if protected_actions.key?(controller) && protected_actions[controller] == action
        data[:controller] = controller
        data[:action] = action
      end

      if event.name == "rate_limit.action_controller"
        limiter = event.payload[:name] || "default"
        data[:limiter] = limiter if controller_limiters.include?(limiter)
      end
    end

    Rails.logger.info(data.to_json)
  end
end
