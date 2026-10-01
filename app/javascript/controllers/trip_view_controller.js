import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tabBtn", "detailsPane", "chatPane"]
  static values = {
    defaultTab: { type: String, default: "details" },
    activeTab: { type: String, default: "details" }
  }

  connect() {
    const urlParams = new URLSearchParams(window.location.search)
    const tabParam = urlParams.get("tab")
    const hash = window.location.hash

    if (tabParam === "chat" || hash === "#chat") {
      this.switchTab("chat")
    } else {
      this.switchTab(this.defaultTabValue)
    }
  }

  showDetails(e) {
    if (e) e.preventDefault()
    this.switchTab("details")
  }

  showChat(e) {
    if (e) e.preventDefault()
    this.switchTab("chat")
  }

  switchTab(tab) {
    this.activeTabValue = tab

    if (this.hasDetailsPaneTarget) {
      if (tab === "details") {
        this.detailsPaneTarget.classList.remove("hidden")
      } else {
        this.detailsPaneTarget.classList.add("hidden")
      }
    }

    if (this.hasChatPaneTarget) {
      if (tab === "chat") {
        this.chatPaneTarget.classList.remove("hidden")
        window.dispatchEvent(new Event("resize"))
      } else {
        this.chatPaneTarget.classList.add("hidden")
      }
    }

    this.tabBtnTargets.forEach((btn) => {
      const isTarget = btn.dataset.tabName === tab
      if (isTarget) {
        btn.classList.add("bg-neutral-900", "text-white", "dark:bg-white", "dark:text-neutral-900", "shadow-xs")
        btn.classList.remove("text-neutral-600", "dark:text-neutral-400", "hover:bg-neutral-100", "dark:hover:bg-neutral-800")
        btn.setAttribute("aria-selected", "true")
      } else {
        btn.classList.remove("bg-neutral-900", "text-white", "dark:bg-white", "dark:text-neutral-900", "shadow-xs")
        btn.classList.add("text-neutral-600", "dark:text-neutral-400", "hover:bg-neutral-100", "dark:hover:bg-neutral-800")
        btn.setAttribute("aria-selected", "false")
      }
    })
  }
}
