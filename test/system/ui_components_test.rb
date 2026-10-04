require "application_system_test_case"

class UiComponentsTest < ApplicationSystemTestCase
  test "password visibility strength and requirements respond to input" do
    mount_components Password::Component.new(name: "password", show_strength: true, show_requirements: true)

    assert_selector "[data-password-target='strengthBar'].bg-neutral-300", visible: :all
    fill_in "Password", with: "a"
    assert_selector "[data-password-target='strengthText']", text: "Weak"
    assert_selector "[data-password-target='lowercaseCheck'].text-green-600"
    assert_selector "[data-password-target='lengthCheck'].text-neutral-500"

    fill_in "Password", with: "Abcdef1!"
    assert_selector "[data-password-target='strengthText']", text: "Strong"
    assert_equal "100%", page.evaluate_script("document.querySelector('[data-password-target=strengthBar]').style.width")
    %w[lengthCheck lowercaseCheck uppercaseCheck numberCheck].each do |target|
      assert_selector "[data-password-target='#{target}'].text-green-600 span.line-through"
    end

    find("button[aria-label='Toggle password visibility']").click
    assert_selector "input[name='password'][type='text']"
    assert_equal "Abcdef1!", find("input[name='password']").value
    find("button[aria-label='Toggle password visibility']").click
    assert_selector "input[name='password'][type='password']"

    # Cuprite's empty fill emits change without an input event.
    find("input[name='password']").send_keys(:end, *Array.new(8, :backspace))
    assert_no_selector "[data-password-target='strengthText']", visible: true
    assert_equal "0%", page.evaluate_script("document.querySelector('[data-password-target=strengthBar]').style.width")
    %w[lengthCheck lowercaseCheck uppercaseCheck numberCheck].each do |target|
      assert_selector "[data-password-target='#{target}'].text-neutral-500"
      assert_no_selector "[data-password-target='#{target}'] span.line-through"
    end
  end

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
