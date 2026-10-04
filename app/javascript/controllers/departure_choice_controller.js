import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["exactTimeField"]

  connect() {
    const checked = this.element.querySelector('input[type="radio"]:checked')
    this.toggle(checked ? checked.value : null)
  }

  change(event) {
    this.toggle(event.target.value)
  }

  toggle(value) {
    if (this.hasExactTimeFieldTarget) {
      if (value === "exact_time") {
        this.exactTimeFieldTarget.classList.remove("hidden")
      } else {
        this.exactTimeFieldTarget.classList.add("hidden")
      }
    }
  }
}
