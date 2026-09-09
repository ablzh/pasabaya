# frozen_string_literal: true

require "test_helper"
require "view_component/test_case"

module Card
  class ComponentTest < ViewComponent::TestCase
    def test_renders_card_with_body
      render_inline(Card::Component.new) do |card|
        card.with_body { "Card body content" }
      end

      assert_selector "div", text: "Card body content"
      assert_selector "div.rounded-xl"
    end

    def test_handles_string_inputs_for_rounded_padding_and_shadow
      render_inline(Card::Component.new(
        rounded: "3xl",
        padding: "lg",
        shadow: "md",
        variant: "elevated"
      )) do |card|
        card.with_body { "Custom styled content" }
      end

      assert_selector "div.rounded-3xl"
      assert_selector "div.shadow-md"
    end

    def test_renders_header_body_and_footer_slots
      render_inline(Card::Component.new(divide: true)) do |card|
        card.with_header { "Header Title" }
        card.with_body { "Body Details" }
        card.with_footer { "Footer Actions" }
      end

      assert_selector "div", text: "Header Title"
      assert_selector "div", text: "Body Details"
      assert_selector "div", text: "Footer Actions"
      assert_selector "div.divide-y"
    end
  end
end
