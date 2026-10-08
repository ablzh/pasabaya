import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tabBtn", "detailsPane", "chatPane"]
  static values = {
    defaultTab: { type: String, default: "details" },
    activeTab: { type: String, default: "details" }
  }

  connect() {
    this.boundRestoreTab = () => this.switchTab(this.selectedTab || this.defaultTabValue)
    document.addEventListener("turbo:morph", this.boundRestoreTab)
    const urlParams = new URLSearchParams(window.location.search)
    const tabParam = urlParams.get("tab")
    const hash = window.location.hash

    if (tabParam === "chat" || hash === "#chat") {
      this.switchTab("chat")
    } else {
      this.switchTab(this.defaultTabValue)
    }
  }

  disconnect() {
    document.removeEventListener("turbo:morph", this.boundRestoreTab)
  }

  showDetails(e) {
    if (e) e.preventDefault()
    this.switchTab("details")
    this.tabBtnTargets.find((button) => button.dataset.tabName === "details")?.focus()
  }

  showChat(e) {
    if (e) e.preventDefault()
    this.switchTab("chat")
  }

  navigateTabs(event) {
    const keys = ["ArrowLeft", "ArrowRight", "Home", "End"]
    if (!keys.includes(event.key)) return
    event.preventDefault()
    const current = this.tabBtnTargets.indexOf(event.currentTarget)
    const last = this.tabBtnTargets.length - 1
    const next = event.key === "Home" ? 0 : event.key === "End" ? last :
      (current + (event.key === "ArrowRight" ? 1 : last)) % this.tabBtnTargets.length
    const button = this.tabBtnTargets[next]
    this.switchTab(button.dataset.tabName)
    button.focus()
  }

  switchTab(tab) {
    if (tab === "chat" && !this.hasChatPaneTarget) tab = "details"
    this.activeTabValue = tab
    this.selectedTab = tab

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
      btn.tabIndex = isTarget ? 0 : -1
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
