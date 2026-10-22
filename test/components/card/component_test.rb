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
    end

    def test_renders_header_body_and_footer_slots
      render_inline(Card::Component.new) do |card|
        card.with_header { "Header Title" }
        card.with_body { "Body Details" }
        card.with_footer { "Footer Actions" }
      end

      assert_selector "div", text: "Header Title"
      assert_selector "div", text: "Body Details"
      assert_selector "div", text: "Footer Actions"
    end
  end
end
