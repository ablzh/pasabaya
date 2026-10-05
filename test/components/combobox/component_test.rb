# frozen_string_literal: true

require "test_helper"
require "view_component/test_case"

module Combobox
  class ComponentTest < ViewComponent::TestCase
    def test_renders_grouped_location_ids_selection_and_turbo_hooks
      rendered = render_inline(Combobox::Component.new(
        name: "ride_post[origin_id]", id: "ride_post_origin_id",
        grouped_options: { "Metro Manila" => [ [ "Quezon City", 12 ], [ "Manila", 13 ] ] },
        selected: 12, placeholder: "Select a city..."
      ))

      assert_selector "select#ride_post_origin_id[name='ride_post[origin_id]'][data-controller='select']" do
        assert_selector "option[value='']", text: "Select a city..."
        assert_selector "optgroup[label='Metro Manila'] option[value='12'][selected]", text: "Quezon City"
        assert_selector "optgroup[label='Metro Manila'] option[value='13']", text: "Manila"
      end
      assert_equal "turbo:before-render@document->select#teardown turbo:render@document->select#connect turbo:before-cache@document->select#teardown",
                   rendered.at_css("select")["data-action"]
    end
  end
end
