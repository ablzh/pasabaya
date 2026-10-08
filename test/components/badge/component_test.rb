# frozen_string_literal: true

require "test_helper"
require "view_component/test_case"

module Badge
  class ComponentTest < ViewComponent::TestCase
    def test_renders_badge_with_text
      render_inline(Badge::Component.new(text: "Active"))
      assert_selector "span", text: "Active"
    end

    def test_renders_pill_and_variants
      render_inline(Badge::Component.new(text: "Ladies Only", variant: :pink, pill: true, size: :sm))
      assert_selector "span.rounded-full", text: "Ladies Only"
      assert_selector "span.bg-pink-50"
    end

    def test_renders_dot_indicator
      render_inline(Badge::Component.new(text: "Live", dot: true))
      assert_selector "span span.rounded-full[aria-hidden='true']"
    end

    def test_renders_with_block_content_and_uppercase
      render_inline(Badge::Component.new(variant: :neutral, size: :sm, pill: true, uppercase: true)) do
        "Full"
      end
      assert_selector "span.uppercase.tracking-wider", text: "Full"
    end

    def test_removable_badge_has_a_named_action
      render_inline(Badge::Component.new(text: "Selected", removable: true))

      assert_selector "[data-controller='badge'] button[aria-label='Remove Selected'][data-action='click->badge#remove']"
    end

    def test_removable_block_content_has_a_default_button_name
      render_inline(Badge::Component.new(removable: true)) { "Selected" }

      assert_selector "button[aria-label='Remove badge']"
    end
  end
end
