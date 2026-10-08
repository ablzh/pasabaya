# frozen_string_literal: true

require "test_helper"
require "view_component/test_case"

module Forms
  class ComponentTest < ViewComponent::TestCase
    def test_uses_explicit_id_for_label_for_attribute
      render_inline(Forms::Component.new(
        label: "First Name",
        name: :first_name,
        id: "user_first_name"
      )) do
        '<input type="text" id="user_first_name" name="user[first_name]"/>'.html_safe
      end

      assert_selector "label[for='user_first_name']", text: "First Name"
      assert_selector "input#user_first_name"
    end

    def test_generates_id_from_name_when_id_not_provided
      render_inline(Forms::Component.new(
        label: "Email",
        name: "user[email_address]"
      )) do
        '<input type="email" id="user_email_address"/>'.html_safe
      end

      assert_selector "label[for='user_email_address']", text: "Email"
    end

    def test_handles_string_inputs_for_size_and_variant
      render_inline(Forms::Component.new(
        label: "Bio",
        name: :bio,
        size: "sm",
        variant: "floating"
      ))

      assert_selector "div.relative"
    end

    def test_displays_error_message
      render_inline(Forms::Component.new(
        label: "Email",
        name: :email,
        error: "can't be blank"
      ))

      assert_selector "p", text: "can't be blank"
      assert_selector "p.text-red-700"
    end

    def test_displays_helper_text
      render_inline(Forms::Component.new(
        label: "Username",
        name: :username,
        helper_text: "Must be alphanumeric."
      ))

      assert_selector "p", text: "Must be alphanumeric."
    end
  end
end
