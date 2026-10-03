# frozen_string_literal: true

module Middleware
  class NativeConfigurationCacheControl
    CACHE_CONTROL = "public, no-cache, must-revalidate"
    CONFIG_PATH_PREFIX = "/configurations/"

    def initialize(app)
      @app = app
    end

    def call(env)
      path_info = env["PATH_INFO"]
      return @app.call(env) unless configuration_request?(path_info)

      status, headers, body = @app.call(env)

      if status == 200 || status == 304
        headers["cache-control"] = CACHE_CONTROL
        headers.delete("Cache-Control") if headers.is_a?(Hash) && headers.key?("Cache-Control")

        # Support If-None-Match ETag revalidation alongside Rack::Files' Last-Modified
        public_path = Rails.public_path.join(path_info.delete_prefix("/"))
        if File.file?(public_path) && File.readable?(public_path)
          mtime = File.mtime(public_path)
          size = File.size(public_path)
          etag = %(W/"#{mtime.to_i.to_s(16)}-#{size.to_s(16)}")
          headers["etag"] ||= etag

          if env["HTTP_IF_NONE_MATCH"] == etag
            body.close if body.respond_to?(:close)
            return [ 304, { "cache-control" => CACHE_CONTROL, "etag" => etag }, [] ]
          end
        end
      end

      [ status, headers, body ]
    end

    private

    def configuration_request?(path_info)
      path_info&.start_with?(CONFIG_PATH_PREFIX)
    end
  end
end
