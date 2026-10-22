# frozen_string_literal: true

module Toast
  class Component < ViewComponent::Base
    def initialize(flash: nil)
      super()
      @flash = flash
    end

    def flash_items
      return [] unless @flash

      @flash.filter_map do |type, message|
        next if message.blank? || %w[alert error feedback_errors].include?(type.to_s)

        toast_type = case type.to_s
        when "alert", "error" then "error"
        when "notice" then "success"
        when "warning" then "warning"
        when "info" then "info"
        else "default"
        end

        { type: toast_type, message: message }
      end
    end
  end
end
