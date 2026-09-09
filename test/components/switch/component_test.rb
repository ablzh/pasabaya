# frozen_string_literal: true

require "test_helper"
require "view_component/test_case"

module Switch
  class ComponentTest < ViewComponent::TestCase
    def test_renders_switch_with_label_and_input
      render_inline(Switch::Component.new(
        label: "Enable notifications",
        name: "notifications"
      ))

      assert_selector "label"
      assert_selector "input[type='checkbox'][name='notifications']"
      assert_selector "span", text: "Enable notifications"
    end

    def test_renders_checked_switch
      render_inline(Switch::Component.new(
        name: "active",
        checked: true
      ))

      assert_selector "input[type='checkbox'][checked]"
    end

    def test_renders_disabled_switch
      render_inline(Switch::Component.new(
        name: "active",
        disabled: true
      ))

      assert_selector "input[type='checkbox'][disabled]"
    end

    def test_handles_string_inputs_for_size_and_label_position
      render_inline(Switch::Component.new(
        label: "Left label",
        size: "lg",
        label_position: "left"
      ))

      assert_selector "label.flex-row-reverse"
    end
  end
end
