# frozen_string_literal: true

module Forms
  class Component < ViewComponent::Base
    SIZES = %i[sm md lg].freeze
    VARIANTS = %i[default floating stacked inline].freeze

    renders_one :input
    renders_one :addon_left
    renders_one :addon_right

    # @param label [String] The form field label text
    # @param name [String] The input name attribute (used for auto-generating id)
    # @param id [String] The input id attribute (auto-generated if not provided)
    # @param required [Boolean] Whether the field is required
    # @param disabled [Boolean] Whether the field is disabled
    # @param helper_text [String] Optional helper text below the input
    # @param error [String] Error message to display
    # @param size [Symbol] Size: :sm (small), :md (medium/default), :lg (large)
    # @param variant [Symbol] Layout variant: :default, :floating, :stacked, :inline
    # @param label_hidden [Boolean] Visually hide the label (still accessible)
    # @param classes [String] Additional CSS classes for the wrapper
    # @param label_classes [String] Additional CSS classes for the label
    # @param input_wrapper_classes [String] Additional CSS classes for the input wrapper
    def initialize(
      label: nil,
      name: nil,
      id: nil,
      required: false,
      disabled: false,
      helper_text: nil,
      error: nil,
      size: :md,
      variant: :default,
      label_hidden: false,
      classes: nil,
      label_classes: nil,
      input_wrapper_classes: nil
    )
      super()
      @label = label
      @name = name
      @id = id || (name ? name.to_s.gsub(/[\[\]]/, "_").gsub(/_+$/, "") : generate_id)
      @required = required
      @disabled = disabled
      @helper_text = helper_text
      @error = error
      normalized_size = size.to_s.to_sym
      @size = SIZES.include?(normalized_size) ? normalized_size : :md
      normalized_variant = variant.to_s.to_sym
      @variant = VARIANTS.include?(normalized_variant) ? normalized_variant : :default
      @label_hidden = label_hidden
      @classes = classes
      @label_classes = label_classes
      @input_wrapper_classes = input_wrapper_classes
    end

    # Pass these attributes to the supplied native input or custom picker.
    def input_attributes
      description_ids = []
      description_ids << "#{@id}_hint" if @helper_text.present?
      description_ids << "#{@id}_error" if @error.present?
      attributes = {}
      attributes[:"aria-describedby"] = description_ids.join(" ") if description_ids.any?
      if @error.present?
        attributes[:"aria-invalid"] = "true"
        if @error.respond_to?(:rule) && @error.rule
          attributes[:"data-form-error-rule"] = @error.rule
          attributes[:"data-form-error-limit"] = @error.limit
        end
      end
      attributes
    end

    def wrapper_classes
      base = case @variant
      when :inline then "flex items-center gap-4"
      when :floating then "relative"
      else "flex flex-col gap-y-1.5"
      end

      [ base, "form-field min-w-0", @classes ].compact.reject(&:empty?).join(" ")
    end

    def label_classes
      base = "font-medium"
      size_class = case @size
      when :sm then "text-xs"
      when :lg then "text-base"
      else "text-sm"
      end

      visibility_class = @label_hidden ? "sr-only" : ""

      color_class = if @disabled
                      "text-neutral-400 dark:text-neutral-500"
      else
                      "text-neutral-700 dark:text-neutral-300"
      end

      width_class = @variant == :inline ? "shrink-0" : ""

      [ base, size_class, visibility_class, color_class, width_class, @label_classes ].compact.reject(&:empty?).join(" ")
    end

    def input_wrapper_classes
      base = @variant == :inline ? "flex-1" : ""
      addon_class = addons? ? "flex" : ""

      [ base, addon_class, @input_wrapper_classes ].compact.reject(&:empty?).join(" ")
    end

    def helper_text_classes
      size_class = case @size
      when :sm then "text-[11px]"
      when :lg then "text-sm"
      else "text-xs"
      end

      color_class = @disabled ? "text-neutral-400 dark:text-neutral-500" : "text-neutral-500 dark:text-neutral-400"

      [ size_class, color_class, "mt-1" ].join(" ")
    end

    def error_classes
      size_class = case @size
      when :sm then "text-[11px]"
      when :lg then "text-sm"
      else "text-xs"
      end

      [ size_class, "text-red-700 dark:text-red-400 mt-1" ].join(" ")
    end

    def addon_classes(position)
      base = "inline-flex items-center px-3 text-neutral-500 dark:text-neutral-400"
      bg = "bg-neutral-100 dark:bg-neutral-700"
      border = "border border-neutral-300 dark:border-neutral-600"

      size_class = case @size
      when :sm then "text-xs"
      when :lg then "text-base"
      else "text-sm"
      end

      position_class = case position
      when :left then "rounded-l-lg border-r-0"
      when :right then "rounded-r-lg border-l-0"
      end

      [ base, bg, border, size_class, position_class ].join(" ")
    end

    def addons?
      addon_left.present? || addon_right.present?
    end

    private

    def generate_id
      "form_field_#{SecureRandom.hex(4)}"
    end

    attr_reader :label, :name, :id, :required, :disabled, :helper_text, :error, :size, :variant, :label_hidden
  end
end
