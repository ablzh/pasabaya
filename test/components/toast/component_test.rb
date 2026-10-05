# frozen_string_literal: true

require "test_helper"
require "view_component/test_case"

module Toast
  class ComponentTest < ViewComponent::TestCase
    def test_renders_one_top_center_host_with_accessible_live_region
      render_inline(Toast::Component.new)

      assert_selector "div#toast-container[data-controller='toast']", count: 1
      assert_selector "#toast-container.left-1\\/2.top-0"
      assert_selector "ol[data-toast-target='container'][aria-live='polite']"
      assert_no_selector "div[data-controller='flash-toasts']"
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
