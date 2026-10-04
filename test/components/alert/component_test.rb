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
      assert_selector ".bg-amber-50"
    end

    def test_renders_error_alert
      render_inline(Alert::Component.new(
        title: "Account Frozen",
        variant: :error
      ))

      assert_selector "p", text: "Account Frozen"
      assert_selector ".bg-red-50"
    end

    def test_iconless_description_stacks_without_an_icon_spacer
      render_inline(Alert::Component.new(title: "Notice", description: "Details", show_icon: false))

      assert_selector ".grid-cols-1 > p", count: 2
      assert_no_selector ".grid-cols-1 > div"
      assert_no_selector "svg"
    end
  end
end
