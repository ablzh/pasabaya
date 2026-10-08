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
