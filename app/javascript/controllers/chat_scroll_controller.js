import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messages", "input", "message"]
  static values = { currentUserId: Number }

  messageTargetConnected(message) {
    message.dataset.ownMessage = String(Number(message.dataset.senderId) === this.currentUserIdValue)
  }

  connect() {
    this.scrollToBottom()
    if (this.hasMessagesTarget) {
      this.observer = new MutationObserver(() => this.scrollToBottom())
      this.observer.observe(this.messagesTarget, { childList: true, subtree: true })
    }
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  scrollToBottom() {
    if (!this.hasMessagesTarget) return

    requestAnimationFrame(() => {
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    })
  }

  resetInput() {
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
    }
  }
}
