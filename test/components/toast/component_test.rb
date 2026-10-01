# frozen_string_literal: true

require "test_helper"
require "view_component/test_case"

module Toast
  class ComponentTest < ViewComponent::TestCase
    def test_renders_container_and_default_data_attributes
      render_inline(Toast::Component.new)

      assert_selector "div#toast-container"
      assert_selector "div[data-controller='toast']"
      assert_selector "div[data-toast-position-value='top-center']"
      assert_selector "div[data-toast-layout-value='default']"
      assert_selector "ol[data-toast-target='container']"
      assert_no_selector "div[data-controller='flash-toasts']"
    end

    def test_renders_custom_position_and_layout
      render_inline(Toast::Component.new(position: "bottom-right", layout: "expanded"))

      assert_selector "div[data-toast-position-value='bottom-right']"
      assert_selector "div[data-toast-layout-value='expanded']"
      assert_selector "div.right-0.bottom-0"
    end

    def test_renders_flash_items_when_flash_present
      flash_hash = {
        "notice" => "Trip was successfully posted!",
        "alert" => "Please confirm your password."
      }

      render_inline(Toast::Component.new(flash: flash_hash))

      assert_selector "div[data-controller='flash-toasts']"
      assert_selector "div[data-flash-toasts-target='item'][data-type='success'][data-message='Trip was successfully posted!']"
      assert_selector "div[data-flash-toasts-target='item'][data-type='error'][data-message='Please confirm your password.']"
    end

    def test_handles_empty_or_blank_flash_messages
      flash_hash = { "notice" => "", "alert" => nil }

      render_inline(Toast::Component.new(flash: flash_hash))

      assert_no_selector "div[data-controller='flash-toasts']"
    end
  end
end
