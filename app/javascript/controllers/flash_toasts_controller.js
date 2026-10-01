import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]

  connect() {
    requestAnimationFrame(() => {
      this.itemTargets.forEach((item) => {
        const type = item.dataset.type || "default"
        const message = item.dataset.message
        if (message) {
          window.dispatchEvent(
            new CustomEvent("toast-show", {
              detail: { type, message }
            })
          )
        }
      })
      this.element.remove()
    })
  }
}
