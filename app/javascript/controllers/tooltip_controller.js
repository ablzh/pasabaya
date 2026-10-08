import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.boundShow = this.show.bind(this);
    this.boundHide = this.hide.bind(this);

    this.element.addEventListener("mouseenter", this.boundShow);
    this.element.addEventListener("mouseleave", this.boundHide);
    this.element.addEventListener("focusin", this.boundShow);
    this.element.addEventListener("focusout", this.boundHide);
  }

  disconnect() {
    this.element.removeEventListener("mouseenter", this.boundShow);
    this.element.removeEventListener("mouseleave", this.boundHide);
    this.element.removeEventListener("focusin", this.boundShow);
    this.element.removeEventListener("focusout", this.boundHide);
    this.hide();
  }

  show() {
    const text = this.element.getAttribute("data-tooltip-content");
    if (!text || this.tooltipEl) return;

    this.tooltipEl = document.createElement("div");
    this.tooltipEl.setAttribute("role", "tooltip");
    this.tooltipEl.className =
      "fixed z-50 px-2 py-1 text-xs text-white bg-neutral-900 dark:bg-neutral-100 dark:text-neutral-900 rounded-md shadow pointer-events-none transition-opacity duration-150";
    this.tooltipEl.textContent = text;
    document.body.appendChild(this.tooltipEl);

    const rect = this.element.getBoundingClientRect();
    const tooltipRect = this.tooltipEl.getBoundingClientRect();

    const top = rect.bottom + 6;
    const left = rect.left + rect.width / 2 - tooltipRect.width / 2;

    this.tooltipEl.style.top = `${top}px`;
    this.tooltipEl.style.left = `${Math.max(8, left)}px`;
  }

  hide() {
    if (this.tooltipEl) {
      this.tooltipEl.remove();
      this.tooltipEl = null;
    }
  }
}
