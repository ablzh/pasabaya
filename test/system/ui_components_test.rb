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
    [ 320, 1440 ].product(%w[light dark]).each do |width, theme|
      page.driver.resize(width, 900)
      page.execute_script("document.documentElement.classList.toggle('dark', arguments[0] === 'dark')", theme)
      ratios = text_contrast(".contrast-alert p")
      assert_equal Alert::Component::VARIANTS.size * 2, ratios.size
      ratios.each { |ratio| assert_operator ratio, :>=, 4.5, "#{theme} alert text contrast" }
      assert page.evaluate_script("[...document.querySelectorAll('.contrast-alert')].every(el => el.scrollWidth <= el.clientWidth)"), "Long descriptions must wrap inside alerts"
    end
  end

  private

  def text_contrast(selector)
    page.evaluate_script(<<~JS, selector)
      (() => {
        const canvas = document.createElement('canvas');
        canvas.width = canvas.height = 1;
        const ctx = canvas.getContext('2d', {willReadFrequently: true});
        const pixel = () => [...ctx.getImageData(0, 0, 1, 1).data].slice(0, 3);
        const paint = color => {ctx.fillStyle = color; ctx.fillRect(0, 0, 1, 1)};
        const luminance = rgb => rgb.map(c => {
          c /= 255;
          return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
        }).reduce((sum, c, i) => sum + c * [0.2126, 0.7152, 0.0722][i], 0);
        return [...document.querySelectorAll(arguments[0])].map(el => {
          ctx.clearRect(0, 0, 1, 1);
          paint('white');
          const ancestors = [];
          for (let node = el; node; node = node.parentElement) ancestors.unshift(node);
          ancestors.forEach(node => paint(getComputedStyle(node).backgroundColor));
          const bg = luminance(pixel());
          paint(getComputedStyle(el).color);
          const fg = luminance(pixel());
          return (Math.max(bg, fg) + 0.05) / (Math.min(bg, fg) + 0.05);
        });
      })()
    JS
  end

  def mount_components(*components)
    visit root_path
    context = ApplicationController.new.view_context
    markup = components.map { |component| component.render_in(context) }.join
    page.execute_script("document.querySelector('main').innerHTML = arguments[0]", markup)
  end
end
