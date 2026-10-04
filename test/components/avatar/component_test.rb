# frozen_string_literal: true

require "test_helper"
require "view_component/test_case"

module Avatar
  class ComponentTest < ViewComponent::TestCase
    def test_renders_avatar_with_image
      render_inline(Avatar::Component.new(
        alt: "Jane Doe",
        src: "https://example.com/avatar.jpg",
        size: :md
      ))

      assert_selector "img[alt='Jane Doe'][src='https://example.com/avatar.jpg']"
    end

    def test_renders_avatar_with_fallback_initials
      render_inline(Avatar::Component.new(
        alt: "Jane Doe",
        fallback: "JD",
        size: :lg
      ))

      assert_selector "span", text: "JD"
    end

    def test_renders_online_presence
      render_inline(Avatar::Component.new(
        alt: "Jane Doe",
        fallback: "JD",
        status: :online
      ))

      assert_selector "span.sr-only", text: "Online"
    end

    def test_preserves_default_dimensions_for_responsive_or_partial_overrides
      [ "sm:size-12", "w-12", "h-12" ].each do |classes|
        render_inline(Avatar::Component.new(alt: "Jane Doe", classes: classes))

        assert_selector "span.size-10[role='img']"
      end
    end

    def test_unconditional_size_override_replaces_default_dimensions
      render_inline(Avatar::Component.new(alt: "Jane Doe", classes: "size-6"))

      assert_selector "span.size-6[role='img']"
      assert_no_selector "span.size-10[role='img']"
    end
  end
end
