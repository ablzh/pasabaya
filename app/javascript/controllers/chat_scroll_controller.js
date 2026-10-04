import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messages", "input", "message", "status", "coordinationNotice"]
  static values = {
    currentUserId: Number,
    readUrl: String,
    messagingClosesAt: String,
    historyUnavailableAt: String,
    writable: Boolean
  }

  initialize() {
    this.boundCheckAndMarkRead = this.checkAndMarkRead.bind(this)
    this.boundOnScroll = this.onScroll.bind(this)
    this.followLatest = true
    this.boundOnResize = this.onResize.bind(this)
    this.lastMarkedMessageId = 0
    this.boundCheckDeadlines = this.checkDeadlines.bind(this)
  }

  messageTargetConnected(message) {
    message.dataset.ownMessage = String(Number(message.dataset.senderId) === this.currentUserIdValue)
    if (this.followLatest && this.isForeground()) {
      this.scrollToBottom()
      this.checkAndMarkRead()
    }
  }

  connect() {
    this.updateViewport()
    this.checkDeadlines()
    this.scrollToBottom()
    if (this.hasMessagesTarget) {
      this.messagesTarget.addEventListener("scroll", this.boundOnScroll, { passive: true })
      this.observer = new MutationObserver(() => {
        if (this.followLatest && this.isForeground()) {
          this.scrollToBottom()
        }
        this.checkAndMarkRead()
      })
      this.observer.observe(this.messagesTarget, { childList: true, subtree: true })
    }

    document.addEventListener("visibilitychange", this.boundCheckDeadlines)
    window.addEventListener("focus", this.boundCheckDeadlines)
    document.addEventListener("visibilitychange", this.boundCheckAndMarkRead)
    window.addEventListener("focus", this.boundCheckAndMarkRead)
    window.addEventListener("resize", this.boundOnResize)
    window.visualViewport?.addEventListener("resize", this.boundOnResize)
    window.visualViewport?.addEventListener("scroll", this.boundOnResize)

    requestAnimationFrame(() => {
      this.checkAndMarkRead()
    })
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
    if (this.hasMessagesTarget) {
      this.messagesTarget.removeEventListener("scroll", this.boundOnScroll)
    }
    clearTimeout(this.deadlineTimer)
    document.removeEventListener("visibilitychange", this.boundCheckDeadlines)
    window.removeEventListener("focus", this.boundCheckDeadlines)
    document.removeEventListener("visibilitychange", this.boundCheckAndMarkRead)
    window.removeEventListener("focus", this.boundCheckAndMarkRead)
    window.removeEventListener("resize", this.boundOnResize)
    window.visualViewport?.removeEventListener("resize", this.boundOnResize)
    window.visualViewport?.removeEventListener("scroll", this.boundOnResize)
  }

  messagingClosesAtValueChanged() {
    if (this.element.isConnected) this.checkDeadlines()
  }

  historyUnavailableAtValueChanged() {
    if (this.element.isConnected) this.checkDeadlines()
  }

  checkDeadlines() {
    clearTimeout(this.deadlineTimer)
    const now = Date.now()
    const history = Date.parse(this.historyUnavailableAtValue)
    const messaging = Date.parse(this.messagingClosesAtValue)
    if (Number.isFinite(history) && now >= history) {
      this.element.replaceChildren()
      this.element.textContent = "Chat history for this trip is no longer available."
      window.Turbo.visit(window.location.href, { action: "replace" })
      return
    }
    if (this.writableValue && Number.isFinite(messaging) && now >= messaging) {
      this.writableValue = false
      const composer = this.element.querySelector("#chat_message_form")
      if (composer) composer.textContent = "Messaging for this trip has closed. You can still read history until scheduled live-database deletion."
      if (this.hasStatusTarget) {
        this.statusTarget.textContent = "Read-only"
        this.statusTarget.className = "px-2.5 py-1 rounded-full text-xs font-semibold bg-neutral-100 text-neutral-600 dark:bg-neutral-800 dark:text-neutral-400"
      }
      if (this.hasCoordinationNoticeTarget) this.coordinationNoticeTarget.textContent = "Trip canceled. Messaging is closed. Chat history remains readable until scheduled deletion."
      this.checkDeadlines()
      return
    }
    const next = [history, this.writableValue ? messaging : NaN].filter(time => Number.isFinite(time) && time > now)
    if (next.length) this.deadlineTimer = setTimeout(this.boundCheckDeadlines, Math.min(Math.min(...next) - now + 1, 2147483647))
  }

  updateViewport() {
    const viewport = window.visualViewport
    this.element.style.setProperty("--chat-viewport-height", `${viewport?.height ?? window.innerHeight}px`)
    this.element.style.setProperty("--chat-viewport-top", `${viewport?.offsetTop ?? 0}px`)
  }

  onResize() {
    this.updateViewport()
    if (this.isForeground() && this.followLatest) {
      this.scrollToBottom()
      this.checkAndMarkRead()
    }
  }

  onScroll() {
    this.followLatest = this.isAtBottom()
    this.checkAndMarkRead()
  }

  scrollToBottom() {
    if (!this.hasMessagesTarget) return

    requestAnimationFrame(() => {
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
      this.checkAndMarkRead()
    })
  }

  resetInput() {
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
    }
  }

  isForeground() {
    if (document.visibilityState === "hidden") return false
    return this.element.getClientRects().length > 0 && !this.element.closest(".hidden")
  }

  isAtBottom() {
    if (!this.hasMessagesTarget) return false
    const threshold = 50
    const distanceToBottom = this.messagesTarget.scrollHeight - this.messagesTarget.scrollTop - this.messagesTarget.clientHeight
    return distanceToBottom <= threshold
  }

  checkAndMarkRead() {
    if (!this.hasReadUrlValue || !this.hasMessagesTarget) return
    if (!this.isForeground()) return
    if (!this.isAtBottom()) return

    const messages = this.messageTargets
    if (messages.length === 0) return

    const lastMessage = messages[messages.length - 1]
    const lastMessageId = Number(lastMessage.dataset.messageId)
    if (!lastMessageId || lastMessageId <= this.lastMarkedMessageId) return

    this.sendMarkRead(lastMessageId)
  }

  sendMarkRead(lastMessageId) {
    this.lastMarkedMessageId = lastMessageId

    const formData = new FormData()
    formData.append("last_message_id", lastMessageId)
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")

    fetch(this.readUrlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": csrfToken,
        "Accept": "application/json"
      },
      body: formData
    }).catch(() => {
      this.lastMarkedMessageId = 0
    })
  }
}
