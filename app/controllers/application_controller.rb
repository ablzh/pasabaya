class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
  etag { hotwire_native_app? if request.format.html? }
  after_action :vary_html_by_client

  private

  def email_rate_limit_key(value)
    Digest::SHA256.hexdigest(value.to_s.strip.downcase)
  end

  def reject_rate_limited_request
    message = "Too many requests. Please wait and try again."
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.append("toast-container", partial: "shared/request_throttled", locals: { message: message }), status: :too_many_requests
      end
      format.html { render "errors/too_many_requests", locals: { message: message }, status: :too_many_requests }
      format.json { render json: { error: message }, status: :too_many_requests }
    end
  end

  def vary_html_by_client
    return unless request.format.html?

    response.headers["Vary"] = (response.headers["Vary"].to_s.split(/,\s*/) + [ "User-Agent" ]).uniq.join(", ")
    response.headers["Cache-Control"] = "private, no-store" if authenticated?
  end
end
