# frozen_string_literal: true

require "test_helper"
require "view_component/test_case"

module Badge
  class ComponentTest < ViewComponent::TestCase
    def test_renders_badge_with_text
      render_inline(Badge::Component.new(text: "Active"))
      assert_selector "span", text: "Active"
    end

    def test_renders_dot_indicator
      render_inline(Badge::Component.new(text: "Live", dot: true))
      assert_selector "[aria-hidden='true']"
    end

    def test_renders_with_block_content
      render_inline(Badge::Component.new) do
        "Full"
      end
      assert_selector "span", text: "Full"
    end
  end
end
