# frozen_string_literal: true

require "test_helper"
require "view_component/test_case"

module Password
  class ComponentTest < ViewComponent::TestCase
    def test_renders_password_input_with_toggle
      render_inline(Password::Component.new(
        name: "user[password]",
        label: "Password",
        show_toggle: true
      ))

      assert_selector "input[type='password'][name='user[password]']"
      assert_selector "button[data-action='click->password#toggle']"
    end

    def test_renders_password_strength_and_requirements
      render_inline(Password::Component.new(
        name: "user[password]",
        show_strength: true,
        show_requirements: true
      ))

      assert_selector "[data-password-target='strengthBar']"
      assert_selector "[data-password-target='lengthCheck']"
    end

    def test_uses_existing_form_error_style
      render_inline(Password::Component.new(error: "Password is invalid"))

      assert_selector "input.form-control.error"
      assert_text "Password is invalid"
    end
  end
end
