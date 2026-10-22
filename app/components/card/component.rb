# frozen_string_literal: true

module Card
  class Component < ViewComponent::Base
    VARIANTS = %i[default elevated well].freeze
    PADDINGS = %i[none sm md lg].freeze
    SHADOWS = %i[none xs sm md lg xl].freeze
    ROUNDED = %i[none sm md lg xl 2xl 3xl full].freeze

    renders_one :header
    renders_one :body
    renders_one :footer

    # @param variant [Symbol] Style variant: :default, :elevated, :well
    # @param padding [Symbol] Content padding: :none, :sm, :md, :lg
    # @param shadow [Symbol] Shadow size: :none, :xs, :sm, :md, :lg, :xl
    # @param rounded [Symbol] Border radius: :none, :sm, :md, :lg, :xl, :full
    # @param border [Boolean] Show border
    # @param hoverable [Boolean] Add hover effects
    # @param divide [Boolean] Add dividers between header, body, footer
    # @param classes [String] Additional CSS classes
    def initialize(
      variant: :default,
      padding: :md,
      shadow: :xs,
      rounded: :xl,
      border: true,
      hoverable: false,
      divide: false,
      classes: nil
    )
      super()
      normalized_variant = variant.to_s.to_sym
      @variant = VARIANTS.include?(normalized_variant) ? normalized_variant : :default
      normalized_padding = padding.to_s.to_sym
      @padding = PADDINGS.include?(normalized_padding) ? normalized_padding : :md
      normalized_shadow = shadow.to_s.to_sym
      @shadow = SHADOWS.include?(normalized_shadow) ? normalized_shadow : :xs
      normalized_rounded = rounded.to_s.to_sym
      @rounded = ROUNDED.include?(normalized_rounded) ? normalized_rounded : :xl
      @border = border
      @hoverable = hoverable
      @divide = divide
      @classes = classes
    end

    def wrapper_classes
      [
        base_classes,
        variant_classes,
        shadow_classes,
        rounded_classes,
        border_classes,
        hover_classes,
        divide_classes,
        @classes
      ].compact.reject(&:empty?).join(" ")
    end

    def header_classes
      [
        header_padding_classes,
        header_background_classes
      ].compact.reject(&:empty?).join(" ")
    end

    def body_classes
      body_padding_classes
    end

    def footer_classes
      [
        footer_padding_classes,
        footer_background_classes
      ].compact.reject(&:empty?).join(" ")
    end

    private

    def base_classes
      "overflow-hidden"
    end

    def variant_classes
      case @variant
      when :well
        "bg-neutral-50 dark:bg-neutral-900/50"
      else # :default (elevated)
        "bg-white dark:bg-neutral-800"
      end
    end

    def shadow_classes
      return "" if @variant == :well

      case @shadow
      when :none then ""
      when :sm then "shadow-sm"
      when :md then "shadow-md"
      when :lg then "shadow-lg"
      when :xl then "shadow-xl"
      else "shadow-xs" # :xs
      end
    end

    def rounded_classes
      case @rounded
      when :none then ""
      when :sm then "rounded-sm"
      when :md then "rounded-md"
      when :lg then "rounded-lg"
      when :"2xl" then "rounded-2xl"
      when :"3xl" then "rounded-3xl"
      when :full then "rounded-full"
      else "rounded-xl" # :xl
      end
    end

    def border_classes
      return "" unless @border

      "border border-black/10 dark:border-white/10"
    end

    def hover_classes
      return "" unless @hoverable

      "transition-all duration-200 hover:shadow-md dark:hover:shadow-neutral-900/50"
    end

    def divide_classes
      return "" unless @divide

      "divide-y divide-black/10 dark:divide-white/10"
    end

    def header_padding_classes
      case @padding
      when :none then ""
      when :sm then "px-3 py-3 sm:px-4"
      when :lg then "px-6 py-6 sm:px-8"
      else "px-4 py-5 sm:px-6" # :md
      end
    end

    def header_background_classes
      return "" unless @divide

      "bg-neutral-50 dark:bg-neutral-900/50 border-b border-black/10 dark:border-white/10"
    end

    def body_padding_classes
      case @padding
      when :none then ""
      when :sm then "px-3 py-3 sm:p-4"
      when :lg then "px-6 py-6 sm:p-8"
      else "px-4 py-5 sm:p-6" # :md
      end
    end

    def footer_padding_classes
      case @padding
      when :none then ""
      when :sm then "px-3 py-3 sm:px-4"
      when :lg then "px-6 py-5 sm:px-8"
      else "px-4 py-4 sm:px-6" # :md
      end
    end

    def footer_background_classes
      "bg-neutral-50 dark:bg-neutral-900/50"
    end

    attr_reader :variant, :padding, :shadow, :rounded, :border, :hoverable, :divide
  end
end
