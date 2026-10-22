require "application_system_test_case"

class UiComponentsTest < ApplicationSystemTestCase
  test "user avatar preserves caller sizing and inherited fallback text styles" do
    visit root_path
    context = ApplicationController.new.view_context
    classes = "w-32 h-32 text-3xl font-semibold text-white"
    markup = context.user_avatar(users(:one), classes: classes) + context.tag.span("Reference", class: "inline-flex #{classes}", id: "avatar-reference")
    page.execute_script("document.querySelector('main').innerHTML = arguments[0]", markup)
    styles = page.evaluate_script(<<~JS)
      (() => {
        const avatar = document.querySelector('main > span');
        const reference = document.querySelector('#avatar-reference');
        const measure = element => {
          const bounds = element.getBoundingClientRect();
          const text = getComputedStyle(element);
          return {width: bounds.width, height: bounds.height, fontSize: text.fontSize, fontWeight: text.fontWeight, color: text.color};
        };
        return {avatar: measure(avatar), fallback: measure(avatar.querySelector('[aria-hidden="true"]')), reference: measure(reference)};
      })()
    JS
    assert_equal styles["reference"], styles["avatar"]
    assert_equal styles["avatar"].slice("fontSize", "fontWeight", "color"), styles["fallback"].slice("fontSize", "fontWeight", "color")
  end

  test "all alert variants wrap long descriptions and meet text contrast in both themes" do
    mount_components(*Alert::Component::VARIANTS.map { |variant|
      Alert::Component.new(title: "#{variant.to_s.titleize} notice", description: "institutional-mailbox-#{'x' * 70}@example.test", variant: variant, classes: "contrast-alert my-3")
    })
    %w[light dark].each do |theme|
      page.driver.resize(320, 900)
      set_theme(theme)
      ratios = text_contrast(".contrast-alert p")
      assert_equal Alert::Component::VARIANTS.size * 2, ratios.size
      ratios.each { |ratio| assert_operator ratio, :>=, 4.5, "#{theme} alert text contrast" }
      assert page.evaluate_script("[...document.querySelectorAll('.contrast-alert')].every(el => el.scrollWidth <= el.clientWidth)"), "Long descriptions must wrap inside alerts"
    end
  end

  test "contrast distinguishes nested surfaces and composites translucent backgrounds and text" do
    visit root_path
    page.execute_script(<<~JS)
      document.documentElement.style.background = 'white';
      document.body.style.background = 'white';
      document.querySelector('main').innerHTML = `
        <section style="background: black">
          <p id="nested-pass" style="color: white">White on nested black</p>
          <p id="nested-fail" style="color: black">Black on nested black</p>
          <div style="background: rgba(255,255,255,0.5)"><p id="alpha-background" style="color: black">Black on gray</p></div>
        </section>
        <section style="background: white">
          <p id="light-pass" style="color: black">Black on white</p>
          <p id="light-fail" style="color: white">White on white</p>
          <p id="alpha-text" style="color: rgba(0,0,0,0.5)">Translucent black on white</p>
        </section>`;
    JS
    assert_in_delta 21, text_contrast("#nested-pass").sole, 0.01
    assert_in_delta 1, text_contrast("#nested-fail").sole, 0.01
    assert_in_delta 21, text_contrast("#light-pass").sole, 0.01
    assert_in_delta 1, text_contrast("#light-fail").sole, 0.01
    assert_in_delta 5.32, text_contrast("#alpha-background").sole, 0.02
    assert_in_delta 4.00, text_contrast("#alpha-text").sole, 0.06
    assert_text_contrast("#nested-pass, #light-pass, #alpha-background")
    assert_raises(Minitest::Assertion) { assert_text_contrast("#nested-fail, #light-fail, #alpha-text") }
  end

  private

  def mount_components(*components)
    visit root_path
    context = ApplicationController.new.view_context
    markup = components.map { |component| component.render_in(context) }.join
    page.execute_script("document.querySelector('main').innerHTML = arguments[0]", markup)
  end
end
