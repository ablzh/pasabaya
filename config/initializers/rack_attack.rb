class Rack::Attack
  # General Throttle: Protect against overall high volume of requests
  # We exclude /assets to prevent blocking legitimate users loading site resources.
  throttle('req/ip', limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?('/assets')
  end

  # Sign Up Protection (IP): Limit brute force account creation
  throttle('sign_up/ip', limit: 5, period: 1.minute) do |req|
    if req.path == '/sign_up' && req.post?
      req.ip
    end
  end

  # Login Protection (IP): Limit brute force login attempts per IP
  throttle('logins/ip', limit: 5, period: 20.seconds) do |req|
    if req.path == '/session' && req.post?
      req.ip
    end
  end

  # Login Protection (Email): Limit brute force login attempts per specific account email
  # This prevents attackers from using a botnet to try many passwords against one account.
  throttle('logins/email', limit: 5, period: 20.seconds) do |req|
    if req.path == '/session' && req.post?
      # Based on SessionsController, email is in params[:email_address]
      email = req.params['email_address']
      email.to_s.downcase.gsub(/\s+/, "").presence
    end
  end
end
