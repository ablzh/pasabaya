// GoatCounter's pixel API accepts explicit fields without count.js collecting URLs.
// https://www.goatcounter.com/help/pixel
const pendingPageviews = new Set();

document.addEventListener("turbo:load", () => {
  const page = document.querySelector('meta[name="analytics-page"]');
  if (!page || document.documentElement.hasAttribute("data-turbo-preview") ||
      document.visibilityState === "prerender" || localStorage.getItem("skipgc") === "t") return;

  const url = new URL("https://pasabaya.goatcounter.com/count");
  url.search = new URLSearchParams({
    p: page.content,
    t: page.dataset.title,
    rnd: crypto.randomUUID(),
  });

  const pixel = new Image(1, 1);
  pendingPageviews.add(pixel);
  pixel.onload = pixel.onerror = () => pendingPageviews.delete(pixel);
  pixel.referrerPolicy = "no-referrer";
  pixel.src = url.href;
});
