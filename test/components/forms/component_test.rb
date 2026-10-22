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

    def test_displays_error_message
      render_inline(Forms::Component.new(
        label: "Email",
        name: :email,
        error: "can't be blank"
      ))

      assert_selector "p", text: "can't be blank"
    end

    def test_displays_helper_text
      render_inline(Forms::Component.new(
        label: "Username",
        name: :username,
        helper_text: "Must be alphanumeric."
      ))

      assert_selector "p", text: "Must be alphanumeric."
    end

    def test_generated_control_ids_use_identity_instead_of_labels
      [ ::Checkbox::Component, ::Radio::Component, ::Switch::Component ].each do |component|
        original = render_inline(component.new(name: "preferences[delivery]", value: "a b", label: "Original label"))
        original_id = original.at_css("input")["id"]
        updated = render_inline(component.new(name: "preferences[delivery]", value: "a b", label: "Updated label"))
        assert_equal original_id, updated.at_css("input")["id"]

        alternate = render_inline(component.new(name: "preferences[delivery]", value: "a-b", label: "Updated label"))
        assert_not_equal original_id, alternate.at_css("input")["id"]

        render_inline(component.new(name: "preferences[delivery]", value: "a b", id: "row_2_delivery", label: "Updated label"))
        assert_selector "input#row_2_delivery"
      end
    end

    def test_controls_without_identity_require_an_explicit_id
      [ ::Checkbox::Component, ::Radio::Component, ::Switch::Component, Forms::Component ].each do |component|
        assert_raises(ArgumentError) { component.new(label: "No input identity") }
      end
      assert_raises(ArgumentError) { ::Radio::Component.new(label: "No radio value", name: "delivery") }
    end
  end
end
