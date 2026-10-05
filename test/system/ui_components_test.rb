require "application_system_test_case"

class UiComponentsTest < ApplicationSystemTestCase
  test "named badge removal works with the keyboard" do
    mount_components Badge::Component.new(text: "Selected", removable: true)

    button = find("button[aria-label='Remove Selected']")
    button.execute_script("this.focus()")
    page.driver.browser.keyboard.type(:Enter)
    assert_no_selector "[data-controller='badge']"
  end

  test "avatars retain dimensions and iconless alerts stack at mobile and desktop widths" do
    mount_components Avatar::Component.new(alt: "Jane Doe", classes: "sm:size-12", html_options: { id: "responsive-avatar" }),
                     Avatar::Component.new(alt: "Jane Doe", classes: "w-12", html_options: { id: "wide-avatar" }),
                     Avatar::Component.new(alt: "Jane Doe", classes: "h-12", html_options: { id: "tall-avatar" }),
                     Avatar::Component.new(alt: "Jane Doe", classes: "size-6", html_options: { id: "small-avatar" }),
                     Alert::Component.new(title: "Notice", description: "Details that should appear beneath the title.", show_icon: false, classes: "review-alert")

    [ 320, 640 ].each do |width|
      page.driver.resize(width, 900)
      expected_responsive_size = width < 640 ? 40 : 48
      { "responsive-avatar" => [ expected_responsive_size, expected_responsive_size ],
        "wide-avatar" => [ 48, 40 ], "tall-avatar" => [ 40, 48 ], "small-avatar" => [ 24, 24 ] }.each do |id, expected|
        bounds = page.evaluate_script("document.getElementById('#{id}').getBoundingClientRect().toJSON()")
        assert_equal expected, bounds.values_at("width", "height")
      end
      bounds = page.evaluate_script("Array.from(document.querySelectorAll('.review-alert p'), p => p.getBoundingClientRect().toJSON())")
      assert_equal bounds.first["left"], bounds.last["left"]
      assert_equal bounds.first["width"], bounds.last["width"]
      assert_operator bounds.last["top"], :>=, bounds.first["bottom"]
    end
  end

  private

  def mount_components(*components)
    visit root_path
    context = ApplicationController.new.view_context
    markup = components.map { |component| component.render_in(context) }.join
    page.execute_script("document.querySelector('main').innerHTML = arguments[0]", markup)
  end
end
