import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]

  connect() {
    requestAnimationFrame(() => {
      this.itemTargets.forEach((item) => {
        const type = item.dataset.type || "default"
        const message = item.dataset.message
        const description = item.dataset.description || ""
        const rideId = item.dataset.rideId

        // If the user is currently viewing the active chat tab on this exact trip, suppress redundant toast
        if (rideId) {
          const currentRideEl = document.querySelector("[data-current-ride-id]")
          if (currentRideEl && currentRideEl.dataset.currentRideId === rideId) {
            const chatPane = document.querySelector("[data-trip-view-target='chatPane']")
            if (chatPane && !chatPane.classList.contains("hidden")) {
              return
            }
          }
        }

        let action = null
        if (item.dataset.actionLabel && item.dataset.actionUrl) {
          const url = item.dataset.actionUrl
          action = {
            label: item.dataset.actionLabel,
            onClick: () => {
              if (window.Turbo) {
                window.Turbo.visit(url)
              } else {
                window.location.href = url
              }
            }
          }
        }

        if (message) {
          window.dispatchEvent(
            new CustomEvent("toast-show", {
              detail: { type, message, description, action }
            })
          )
        }
      })
      this.element.remove()
    })
  }
}
