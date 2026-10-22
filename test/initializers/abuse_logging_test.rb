require "test_helper"
require "stringio"

class AbuseLoggingTest < ActiveSupport::TestCase
  test "controller limits log only operation and limiter names" do
    request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/passwords?email_address=private@example.com"))
    request.path_parameters = { controller: "passwords", action: "create" }

    record = capture_abuse_record do
      ActiveSupport::Notifications.instrument("rate_limit.action_controller",
        request: request, scope: "passwords", name: "recipient-minute",
        by: "private@example.com", cache_key: "private-cache-key", remote_ip: "203.0.113.77")
    end

    assert_equal({ "event" => "rate_limit.action_controller", "controller" => "passwords",
      "action" => "create", "limiter" => "recipient-minute" }, record)
  end

  test "honeypot events exclude messages and all submitted request data" do
    record = capture_abuse_record do
      ActiveSupport::Notifications.instrument("invisible_captcha.spam_detected",
        controller: "registrations", action: "create",
        message: "Private captcha message", remote_ip: "203.0.113.77",
        user_agent: "Private user agent", url: "https://private.example.com",
        params: { email_address: "private@example.com", contact_reference: "Private honeypot text" })
    end

    assert_equal({ "event" => "invisible_captcha.spam_detected", "controller" => "registrations",
      "action" => "create" }, record)
  end

  test "Rack Attack logs a single event with the configured limiter name" do
    request = Rack::Attack::Request.new(Rack::MockRequest.env_for("/sign_up?email_address=private@example.com",
      "REMOTE_ADDR" => "203.0.113.77", "HTTP_USER_AGENT" => "Private user agent"))
    request.env["rack.attack.matched"] = "sign_up/ip"
    request.env["rack.attack.match_type"] = :throttle
    request.env["rack.attack.match_discriminator"] = "private@example.com"

    record = capture_abuse_record { Rack::Attack.instrument(request) }

    assert_equal({ "event" => "throttle.rack_attack", "limiter" => "sign_up/ip" }, record)
  end

  test "unrecognized operation names cannot inject sensitive text into logs" do
    request = Struct.new(:path_parameters, :env).new(
      { controller: "private@example.com", action: "Private action" },
      { "rack.attack.matched" => "Private honeypot text" }
    )

    {
      "rate_limit.action_controller" => { request: request, name: "Private limiter" },
      "invisible_captcha.spam_detected" => { controller: "private@example.com", action: "Private action" },
      "throttle.rack_attack" => { request: request }
    }.each do |event_name, payload|
      record = capture_abuse_record { ActiveSupport::Notifications.instrument(event_name, payload) }
      assert_equal({ "event" => event_name }, record)
    end
  end

  private

  def capture_abuse_record
    output = StringIO.new
    with_stubbed_method(Rails, :logger, ActiveSupport::Logger.new(output)) { yield }
    assert_equal 1, output.string.lines.size
    JSON.parse(output.string)
  end
end
