import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["trigger", "content", "viewport", "indicator", "menu", "background"];

  connect() {
    this.activeTrigger = null;
    this.activeContent = null;

    this.boundClickOutside = this.handleClickOutside.bind(this);
    this.boundKeydown = this.handleKeydown.bind(this);
    this.boundFocusOutside = (event) => {
      if (!this.element.contains(event.target)) this.close();
    };
    this.boundResize = () => {
      if (this.activeTrigger) this.positionViewport(this.activeTrigger);
    };

    document.addEventListener("click", this.boundClickOutside);
    document.addEventListener("keydown", this.boundKeydown);
    document.addEventListener("focusin", this.boundFocusOutside);
    window.addEventListener("resize", this.boundResize);
  }

  disconnect() {
    document.removeEventListener("click", this.boundClickOutside);
    document.removeEventListener("keydown", this.boundKeydown);
    document.removeEventListener("focusin", this.boundFocusOutside);
    window.removeEventListener("resize", this.boundResize);
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

  close(restoreFocus = false) {
    if (restoreFocus) this.activeTrigger?.focus();
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
    if (event.key === "Escape" && this.activeTrigger) {
      event.preventDefault();
      this.close(true);
      return;
    }
    if (!this.activeContent?.contains(event.target)) return;
    if (!["ArrowDown", "ArrowUp", "Home", "End"].includes(event.key)) return;

    event.preventDefault();
    const links = Array.from(this.activeContent.querySelectorAll("a[href], button:not([disabled])"));
    const index = links.indexOf(document.activeElement);
    let next = event.key === "ArrowUp" ? index - 1 : index + 1;
    if (event.key === "Home") next = 0;
    if (event.key === "End") next = links.length - 1;
    links[(next + links.length) % links.length]?.focus();
  }

  // Stubs for optional template-registered events
  handlePointerEnter() {}
  handlePointerMove() {}
  handlePointerLeave() {}
  cancelClose() {}
  handleTriggerKeydown(event) {
    if (!["ArrowDown", "ArrowUp"].includes(event.key)) return;
    event.preventDefault();
    event.stopPropagation();
    this.open(event.currentTarget, event.currentTarget.dataset.contentId);
    const links = this.activeContent?.querySelectorAll("a[href], button:not([disabled])");
    const index = event.key === "ArrowUp" ? links.length - 1 : 0;
    links?.[index]?.focus();
  }
}
