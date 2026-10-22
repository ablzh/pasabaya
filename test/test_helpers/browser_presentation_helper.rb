# frozen_string_literal: true

module BrowserPresentationHelper
  def resize_and_visit(width, path, theme = "light")
    page.driver.resize(width, 844)
    visit path
    set_theme(theme)
  end

  def set_theme(theme)
    page.execute_script("localStorage.setItem('theme', arguments[0]); document.documentElement.classList.toggle('dark', arguments[0] === 'dark'); document.documentElement.style.colorScheme = arguments[0]", theme)
  end

  def assert_document_contained
    assert page.evaluate_script("document.scrollingElement.scrollWidth <= document.scrollingElement.clientWidth + 1"), "Document must not scroll horizontally"
  end

  def assert_contained(selector, container, text: false, parent: false)
    bounds = page.evaluate_script(<<~JS, selector, container, text, parent)
      ((selector, container, measureText, parent) => [...document.querySelectorAll(selector)].filter(el => el.getClientRects().length).map(el => {
        const outer = parent ? el.parentElement : el.closest(container) || document.querySelector(container);
        const range = document.createRange(); range.selectNodeContents(el);
        const r = measureText ? range.getBoundingClientRect() : el.getBoundingClientRect(), p = outer.getBoundingClientRect();
        return {text:el.textContent.slice(0,50), left:r.left, right:r.right, outerLeft:p.left, outerRight:p.right, scroll:el.scrollWidth, width:el.clientWidth};
      }))(arguments[0], arguments[1], arguments[2], arguments[3])
    JS
    assert_not_empty bounds, selector
    bounds.each do |r|
      assert_operator r["left"], :>=, r["outerLeft"] - 1, "#{selector} left edge: #{r['text']}"
      assert_operator r["right"], :<=, r["outerRight"] + 1, "#{selector} right edge: #{r['text']}"
      assert_operator r["scroll"], :<=, r["width"] + 1, "#{selector} clips content: #{r['text']}" unless text
    end
  end

  def assert_text_contrast(selector, threshold = 4.5)
    ratios = text_contrast(selector)
    assert_not_empty ratios, "No visible text matched #{selector}"
    ratios.each { |ratio| assert_operator ratio, :>=, threshold, "#{selector} text contrast" }
  end

  # Composite solid and translucent ancestor backgrounds, then the text color.
  # Images, gradients and group opacity need pixel-based review; fail explicitly
  # instead of reporting a misleading ratio for unsupported surfaces.
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
        return [...document.querySelectorAll(arguments[0])].filter(el => el.getClientRects().length).map(el => {
          ctx.clearRect(0, 0, 1, 1);
          paint('white');
          const ancestors = [];
          for (let node = el; node; node = node.parentElement) ancestors.unshift(node);
          ancestors.forEach(node => {
            const style = getComputedStyle(node);
            if (style.backgroundImage !== 'none' || Number(style.opacity) !== 1 || style.filter !== 'none' || style.mixBlendMode !== 'normal') {
              throw new Error('Contrast helper requires solid backgrounds without group opacity, filters or blending');
            }
            paint(style.backgroundColor);
          });
          const bg = luminance(pixel());
          paint(getComputedStyle(el).color);
          const fg = luminance(pixel());
          return (Math.max(bg, fg) + 0.05) / (Math.min(bg, fg) + 0.05);
        });
      })()
    JS
  end
end
