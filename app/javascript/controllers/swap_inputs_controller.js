import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["origin", "destination"]

  swap(event) {
    if (event) event.preventDefault()

    const origin = this.hasOriginTarget ? this.originTarget : this.element.querySelector("#origin_id")
    const dest = this.hasDestinationTarget ? this.destinationTarget : this.element.querySelector("#destination_id")

    if (!origin || !dest) return

    const originVal = origin.tomselect ? origin.tomselect.getValue() : origin.value
    const destVal = dest.tomselect ? dest.tomselect.getValue() : dest.value

    if (origin.tomselect) {
      origin.tomselect.setValue(destVal)
    } else {
      origin.value = destVal
    }

    if (dest.tomselect) {
      dest.tomselect.setValue(originVal)
    } else {
      dest.value = originVal
    }
  }
}
