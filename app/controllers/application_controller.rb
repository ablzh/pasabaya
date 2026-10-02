class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
  etag { hotwire_native_app? if request.format.html? }
  after_action :vary_html_by_client

  private

  def vary_html_by_client
    return unless request.format.html?

    response.headers["Vary"] = (response.headers["Vary"].to_s.split(/,\s*/) + [ "User-Agent" ]).uniq.join(", ")
    response.headers["Cache-Control"] = "private, no-store" if authenticated?
  end
end
