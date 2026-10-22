# frozen_string_literal: true

require "test_helper"
require "view_component/test_case"

module Alert
  class ComponentTest < ViewComponent::TestCase
    def test_renders_alert_with_title_and_description
      render_inline(Alert::Component.new(
        title: "Private Draft",
        description: "Draft details here",
        variant: :warning
      ))

      assert_selector "p", text: "Private Draft"
      assert_text "Draft details here"
    end
  end
end
