import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["trigger", "content", "viewport", "indicator", "menu", "background"];

  connect() {
    this.activeTrigger = null;
    this.activeContent = null;

    this.boundClickOutside = this.handleClickOutside.bind(this);
    this.boundKeydown = this.handleKeydown.bind(this);

    document.addEventListener("click", this.boundClickOutside);
    document.addEventListener("keydown", this.boundKeydown);
  }

  disconnect() {
    document.removeEventListener("click", this.boundClickOutside);
    document.removeEventListener("keydown", this.boundKeydown);
    this.close();
  }

  toggleMenu(event) {
    event.stopPropagation();
    const trigger = event.currentTarget;
    const contentId = trigger.dataset.contentId;

    if (this.activeTrigger === trigger) {
      this.close();
    } else {
      this.open(trigger, contentId);
    }
  }

  open(trigger, contentId) {
    this.close();

    const content = this.contentTargets.find((el) => el.id === contentId);
    if (!content) return;

    this.activeTrigger = trigger;
    this.activeContent = content;

    trigger.dataset.state = "open";
    trigger.setAttribute("aria-expanded", "true");

    content.classList.remove("hidden");
    content.dataset.state = "open";

    if (this.hasViewportTarget) {
      this.positionViewport(trigger);
      this.viewportTarget.dataset.state = "open";
    }
  }

  close() {
    if (this.activeTrigger) {
      this.activeTrigger.dataset.state = "closed";
      this.activeTrigger.setAttribute("aria-expanded", "false");
      this.activeTrigger = null;
    }

    if (this.activeContent) {
      this.activeContent.classList.add("hidden");
      this.activeContent.dataset.state = "closed";
      this.activeContent = null;
    }

    if (this.hasViewportTarget) {
      this.viewportTarget.dataset.state = "closed";
    }
  }

  positionViewport(trigger) {
    const triggerRect = trigger.getBoundingClientRect();
    const parentRect = this.viewportTarget.parentElement.getBoundingClientRect();
    const viewportWidth = this.viewportTarget.offsetWidth || 200;

    let viewportLeft;
    if (trigger.dataset.align === "end") {
      viewportLeft = triggerRect.right - viewportWidth;
    } else if (trigger.dataset.align === "start") {
      viewportLeft = triggerRect.left;
    } else {
      viewportLeft = (triggerRect.left + triggerRect.right) / 2 - viewportWidth / 2;
    }

    viewportLeft = Math.max(16, Math.min(viewportLeft, window.innerWidth - viewportWidth - 16));
    const relativeLeft = viewportLeft - parentRect.left;
    this.viewportTarget.style.left = `${relativeLeft}px`;

    if (this.hasIndicatorTarget) {
      const triggerCenter = triggerRect.left + triggerRect.width / 2;
      const indicatorLeft = triggerCenter - viewportLeft - 20;
      this.indicatorTarget.style.left = `${indicatorLeft}px`;
    }
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close();
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close();
    }
  }

  // Stubs for optional template-registered events
  handlePointerEnter() {}
  handlePointerMove() {}
  handlePointerLeave() {}
  cancelClose() {}
  handleTriggerKeydown(event) {
    if (event.key === "Escape") this.close();
  }
}
