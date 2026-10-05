InvisibleCaptcha.setup do |config|
  # Fast autofill and Turbo-restored forms are legitimate submissions.
  # Use the honeypot alongside server rate limits, without timing or spinner checks.
  config.timestamp_enabled = false
  config.spinner_enabled = false
end
