# frozen_string_literal: true

module Toast
  class Component < ViewComponent::Base
    TYPES = %i[default success error info warning danger loading].freeze
    POSITIONS = %w[top-left top-center top-right bottom-left bottom-center bottom-right].freeze
    LAYOUTS = %w[default expanded].freeze

    # @param position [String] Toast container position: "top-left", "top-center", "top-right", "bottom-left", "bottom-center", "bottom-right"
    # @param layout [String] Layout mode: "default" (stacked) or "expanded" (all visible)
    # @param auto_dismiss_duration [Integer] Duration in milliseconds before auto-dismiss (default: 4000)
    # @param limit [Integer] Maximum number of visible toasts (default: 3)
    # @param gap [Integer] Gap between toasts in expanded mode (default: 14)
    # @param flash [ActionDispatch::Flash::FlashHash, Hash, nil] Flash notices/alerts to display
    # @param classes [String] Additional CSS classes for the container
    def initialize(
      position: "top-center",
      layout: "default",
      auto_dismiss_duration: 4000,
      limit: 3,
      gap: 14,
      flash: nil,
      classes: nil
    )
      super()
      @position = POSITIONS.include?(position) ? position : "top-center"
      @layout = LAYOUTS.include?(layout) ? layout : "default"
      @auto_dismiss_duration = auto_dismiss_duration
      @limit = limit
      @gap = gap
      @flash = flash
      @classes = classes
    end

    def container_classes
      base = "fixed inset-auto m-0 z-[99999] w-[calc(100%-2rem)] sm:w-96 p-0 border-0 bg-transparent overflow-visible pointer-events-none"
      [ base, position_classes, @classes ].compact.reject(&:empty?).join(" ")
    end

    def flash_items
      return [] unless @flash

      @flash.filter_map do |type, message|
        next if message.blank?

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

    private

    def position_classes
      case @position
      when "top-right"
        "right-0 top-0 mt-4 mr-4 sm:mt-6 sm:mr-6"
      when "top-left"
        "left-0 top-0 mt-4 ml-4 sm:mt-6 sm:ml-6"
      when "top-center"
        "left-1/2 -translate-x-1/2 top-0 mt-4 sm:mt-6"
      when "bottom-right"
        "right-0 bottom-0 mb-4 mr-4 sm:mr-6 sm:mb-6"
      when "bottom-left"
        "left-0 bottom-0 mb-4 ml-4 sm:ml-6 sm:mb-6"
      when "bottom-center"
        "left-1/2 -translate-x-1/2 bottom-0 mb-4 sm:mb-6"
      else
        "left-1/2 -translate-x-1/2 top-0 mt-4 sm:mt-6"
      end
    end
  end
end
