# frozen_string_literal: true

require "test_helper"
require "view_component/test_case"

module DarkModeSwitcher
  class ComponentTest < ViewComponent::TestCase
    def test_renders_cycle_icon_variant
      render_inline(DarkModeSwitcher::Component.new(variant: :cycle_icon))

      assert_selector "button.size-9.rounded-full"
      assert_selector "button[data-controller='tooltip']"
      assert_selector "button[data-tooltip-content='Change theme']"
      assert_no_selector "[data-theme-target='cycleLabel']"
      assert_selector "svg[data-theme-mode='system']:not([hidden])", visible: :all
      assert_selector "svg[data-theme-mode='light'][hidden]", visible: :all
      assert_selector "svg[data-theme-mode='dark'][hidden]", visible: :all
    end

    def test_renders_cycle_pill_variant
      render_inline(DarkModeSwitcher::Component.new(variant: :cycle))

      assert_selector "button.min-w-28"
      assert_selector "[data-theme-target='cycleLabel']", text: "System"
    end

    def test_renders_segmented_variant
      render_inline(DarkModeSwitcher::Component.new(variant: :segmented))

      assert_selector "[role='radiogroup'][aria-label='Theme selection']"
      assert_selector "button[role='radio']", count: 3
    end

    def test_handles_string_variant_input
      render_inline(DarkModeSwitcher::Component.new(variant: "cycle_icon"))

      assert_selector "button.size-9.rounded-full"
      assert_selector "button[data-controller='tooltip']"
    end
  end
end
