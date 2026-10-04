import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messages", "input", "message"]
  static values = {
    currentUserId: Number,
    readUrl: String
  }

  initialize() {
    this.boundCheckAndMarkRead = this.checkAndMarkRead.bind(this)
    this.boundOnScroll = this.onScroll.bind(this)
    this.followLatest = true
    this.boundOnResize = this.onResize.bind(this)
    this.lastMarkedMessageId = 0
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
    document.removeEventListener("visibilitychange", this.boundCheckAndMarkRead)
    window.removeEventListener("focus", this.boundCheckAndMarkRead)
    window.removeEventListener("resize", this.boundOnResize)
    window.visualViewport?.removeEventListener("resize", this.boundOnResize)
    window.visualViewport?.removeEventListener("scroll", this.boundOnResize)
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
