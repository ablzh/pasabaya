# frozen_string_literal: true

require "test_helper"
require "view_component/test_case"

module DarkModeSwitcher
  class ComponentTest < ViewComponent::TestCase
    def test_renders_segmented_variant
      render_inline(DarkModeSwitcher::Component.new(variant: :segmented))

      assert_selector "[role='radiogroup'][aria-label='Theme selection']"
      assert_selector "button[role='radio']", count: 3
    end
  end
end
