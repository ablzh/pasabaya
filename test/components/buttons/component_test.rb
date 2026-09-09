# frozen_string_literal: true

require "test_helper"
require "view_component/test_case"

module Buttons
  class ComponentTest < ViewComponent::TestCase
    def test_renders_button_with_text
      render_inline(Buttons::Component.new(text: "Click Me"))
      assert_selector "button", text: "Click Me"
      assert_selector "button[type='button']"
    end

    def test_renders_with_custom_block_content
      render_inline(Buttons::Component.new) do
        "<span>Custom Block Content</span>".html_safe
      end
      assert_selector "button span", text: "Custom Block Content"
    end

    def test_renders_as_link_when_href_provided
      render_inline(Buttons::Component.new(text: "Link Button", href: "/test-path"))
      assert_selector "a[href='/test-path'][role='button']", text: "Link Button"
    end

    def test_handles_string_inputs_for_variant_size_and_style
      render_inline(Buttons::Component.new(
        text: "String Options",
        variant: "destructive",
        size: "sm",
        style: "fancy"
      ))
      assert_selector "button.bg-red-600"
    end

    def test_handles_unknown_variant_fallback_without_error
      render_inline(Buttons::Component.new(text: "Fallback", variant: :unknown_variant))
      assert_selector "button", text: "Fallback"
      # Should fallback to primary styles
      assert_selector "button.bg-neutral-800"
    end

    def test_renders_disabled_button
      render_inline(Buttons::Component.new(text: "Disabled", disabled: true))
      assert_selector "button[disabled]"
    end

    def test_renders_loading_spinner
      render_inline(Buttons::Component.new(text: "Loading...", loading: true))
      assert_selector "button[disabled]"
      assert_selector "button svg.animate-spin"
    end
  end
end
