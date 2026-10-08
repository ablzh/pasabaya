# frozen_string_literal: true

module Badge
  class Component < ViewComponent::Base
    VARIANTS = %i[neutral red orange yellow green blue purple pink rose indigo].freeze
    SIZES = %i[sm md].freeze

    # @param text [String, nil] The badge text content (can also be passed as block content)
    # @param variant [Symbol] Color variant
    # @param size [Symbol] Size: :sm (micro/card size), :md (regular)
    # @param pill [Boolean] Whether to use pill shape (rounded-full)
    # @param uppercase [Boolean] Whether to use uppercase tracking-wider font-bold
    # @param dot [Boolean] Whether to show a colored dot indicator
    # @param removable [Boolean] Whether to show a remove button
    # @param classes [String] Additional CSS classes
    def initialize(text: nil, variant: :neutral, size: :md, pill: false, uppercase: false, dot: false, removable: false, classes: nil)
      super()
      @text = text
      @variant = VARIANTS.include?(variant) ? variant : :neutral
      @size = SIZES.include?(size) ? size : :md
      @pill = pill
      @uppercase = uppercase
      @dot = dot
      @removable = removable
      @classes = classes
    end

    def wrapper_classes
      [
        base_classes,
        size_classes,
        shape_classes,
        typography_classes,
        colors[:bg],
        colors[:text],
        colors[:border],
        @classes
      ].compact.reject(&:blank?).join(" ")
    end

    def colors
      @colors ||= case @variant
      when :red
        {
          bg: "bg-red-50 dark:bg-red-950/40",
          text: "text-red-700 dark:text-red-300",
          border: "border border-red-200 dark:border-red-800",
          dot: "bg-red-500 dark:bg-red-400",
          button_bg: "bg-red-100 dark:bg-red-900/50",
          button_text: "text-red-600 dark:text-red-300",
          button_hover: "hover:bg-red-200 dark:hover:bg-red-800"
        }
      when :orange, :yellow
        {
          bg: "bg-amber-100 dark:bg-amber-950/50",
          text: "text-amber-800 dark:text-amber-300",
          border: "border border-amber-300 dark:border-amber-800",
          dot: "bg-amber-500 dark:bg-amber-400",
          button_bg: "bg-amber-200 dark:bg-amber-900/50",
          button_text: "text-amber-700 dark:text-amber-300",
          button_hover: "hover:bg-amber-300 dark:hover:bg-amber-800"
        }
      when :green
        {
          bg: "bg-emerald-100 dark:bg-emerald-950/60",
          text: "text-emerald-800 dark:text-emerald-300",
          border: "border border-emerald-300 dark:border-emerald-800",
          dot: "bg-emerald-500 dark:bg-emerald-400",
          button_bg: "bg-emerald-200 dark:bg-emerald-900/50",
          button_text: "text-emerald-700 dark:text-emerald-300",
          button_hover: "hover:bg-emerald-300 dark:hover:bg-emerald-800"
        }
      when :blue
        {
          bg: "bg-blue-100 dark:bg-blue-950/60",
          text: "text-blue-700 dark:text-blue-300",
          border: nil,
          dot: "bg-blue-500 dark:bg-blue-400",
          button_bg: "bg-blue-200 dark:bg-blue-900/50",
          button_text: "text-blue-600 dark:text-blue-300",
          button_hover: "hover:bg-blue-300 dark:hover:bg-blue-800"
        }
      when :purple, :indigo
        {
          bg: "bg-purple-50 dark:bg-purple-950/40",
          text: "text-purple-700 dark:text-purple-300",
          border: nil,
          dot: "bg-purple-500 dark:bg-purple-400",
          button_bg: "bg-purple-100 dark:bg-purple-900/50",
          button_text: "text-purple-600 dark:text-purple-300",
          button_hover: "hover:bg-purple-200 dark:hover:bg-purple-800"
        }
      when :pink
        {
          bg: "bg-pink-50 dark:bg-pink-950/40",
          text: "text-pink-700 dark:text-pink-300",
          border: "border border-pink-200 dark:border-pink-800/40",
          dot: "bg-pink-500 dark:bg-pink-400",
          button_bg: "bg-pink-100 dark:bg-pink-900/50",
          button_text: "text-pink-600 dark:text-pink-300",
          button_hover: "hover:bg-pink-200 dark:hover:bg-pink-800"
        }
      when :rose
        {
          bg: "bg-rose-50 dark:bg-rose-950/40",
          text: "text-rose-700 dark:text-rose-300",
          border: nil,
          dot: "bg-rose-500 dark:bg-rose-400",
          button_bg: "bg-rose-100 dark:bg-rose-900/50",
          button_text: "text-rose-600 dark:text-rose-300",
          button_hover: "hover:bg-rose-200 dark:hover:bg-rose-800"
        }
      else # :neutral
        {
          bg: "bg-neutral-200 dark:bg-neutral-800",
          text: "text-neutral-700 dark:text-neutral-300",
          border: nil,
          dot: "bg-neutral-500 dark:bg-neutral-400",
          button_bg: "bg-neutral-300 dark:bg-neutral-700",
          button_text: "text-neutral-600 dark:text-neutral-300",
          button_hover: "hover:bg-neutral-400 dark:hover:bg-neutral-600"
        }
      end
    end

    def remove_button_classes
      button_shape = @pill ? "rounded-full" : "rounded"
      [
        button_shape,
        colors[:button_bg],
        colors[:button_text],
        colors[:button_hover],
        button_size_classes,
        "focus-visible:outline-neutral-500 dark:focus-visible:outline-neutral-400"
      ].compact.join(" ")
    end

    def dot_classes
      [
        "rounded-full",
        colors[:dot],
        dot_size_classes
      ].compact.join(" ")
    end

    private

    def base_classes
      "inline-flex min-w-0 max-w-full items-center [overflow-wrap:anywhere] select-none"
    end

    def typography_classes
      if @uppercase
        "font-bold uppercase tracking-wider"
      else
        "font-semibold"
      end
    end

    def size_classes
      case @size
      when :sm
        addon? ? "gap-1 px-2 py-0.5 text-[10px]" : "px-2 py-0.5 text-[10px]"
      else # :md
        addon? ? "gap-1.5 px-2.5 py-0.5 text-xs" : "px-2.5 py-0.5 text-xs"
      end
    end

    def shape_classes
      @pill ? "rounded-full" : "rounded-md"
    end

    def button_size_classes
      @size == :sm ? "p-0.5 text-[10px]" : "p-0.5 text-xs"
    end

    def dot_size_classes
      @size == :sm ? "size-1.5" : "size-2"
    end

    def icon_size_classes
      @size == :sm ? "size-2.5" : "size-3"
    end

    def addon?
      @dot || @removable
    end

    def render?
      @text.present? || content?
    end

    attr_reader :text, :dot, :removable, :size

    def icon_size
      icon_size_classes
    end
  end
end
