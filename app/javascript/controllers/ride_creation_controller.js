import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["typeGroup", "oneTimeFields", "regularFields", "endDateFields", "endDateToggle", "endDate", "weekday", "date", "departureChoice", "time", "seats", "seatsLabel", "publishButton", "summary"]
  static values = { regular: Boolean }

  connect() {
    this.updateType()
  }

  changeType() {
    this.updateType()
  }

  restoreDraft() {
    this.updateType()
    this.changeEndDate({ target: this.endDateToggleTarget.querySelector("input") })
  }

  updateType() {
    const selected = this.hasTypeGroupTarget ? this.typeGroupTarget.querySelector('input[name="ride_type"]:checked') : null
    this.regularValue = selected ? selected.value === "regular" : this.regularValue
    this.oneTimeFieldsTarget.hidden = this.regularValue
    this.oneTimeFieldsTarget.disabled = this.regularValue
    this.regularFieldsTarget.hidden = !this.regularValue
    this.regularFieldsTarget.disabled = !this.regularValue
    this.seatsLabelTarget.textContent = this.regularValue ? "Passenger seats per departure" : "Available passenger seats"
    if (this.hasPublishButtonTarget) {
      this.publishButtonTarget.textContent = this.regularValue ? "Publish regular ride" : "Publish ride"
    }
    const summary = this.element.querySelector("[data-form-errors-summary]")
    if (summary) {
      const entries = [...summary.querySelectorAll("li")]
      entries.forEach(entry => {
        const field = document.getElementById(entry.dataset.errorFor)
        entry.hidden = Boolean(field?.closest("fieldset[disabled]"))
      })
      summary.hidden = entries.every(entry => entry.hidden)
    }
    this.updateSummary()
  }

  changeEndDate(event) {
    this.endDateFieldsTarget.hidden = !event.target.checked
    this.endDateFieldsTarget.disabled = !event.target.checked
    this.updateSummary()
  }

  selectWeekdays() {
    this.selectDays(["1", "2", "3", "4", "5"])
  }

  selectEveryDay() {
    this.selectDays(["0", "1", "2", "3", "4", "5", "6"])
  }

  selectDays(days) {
    this.weekdayTargets.forEach(input => {
      input.checked = days.includes(input.value)
      input.dispatchEvent(new Event("change", { bubbles: true }))
    })
    this.updateSummary()
  }

  updateSummary() {
    const days = this.weekdayTargets.filter(input => input.checked).map(input => input.dataset.dayLabel)
    const date = this.dateTarget.value
    const schedule = this.regularValue ? (days.join(", ") || "Choose days of the week") : (date ? this.formatDate(date) : "Choose a departure date")
    const choice = this.departureChoiceTargets.find(input => input.checked)?.value
    const time = choice === "exact_time" ? (this.timeTarget.value || "Choose a departure time") : {
      morning: "Morning · 06:00–12:00", afternoon: "Afternoon · 12:00–17:00", evening: "Evening · 17:00–21:00", night: "Night · 21:00–midnight", flexible: "Flexible"
    }[choice]
    const seats = Number(this.seatsTarget.value)
    const capacity = seats > 0 ? `${seats} passenger ${seats === 1 ? "seat" : "seats"}${this.regularValue ? " per departure" : ""}` : null
    const until = this.regularValue && !this.endDateFieldsTarget.disabled && this.endDateTarget.value ? `until ${this.formatDate(this.endDateTarget.value)}` : null
    this.summaryTarget.textContent = [schedule, time, capacity, until].filter(Boolean).join(" • ")
  }

  formatDate(value) {
    return new Intl.DateTimeFormat("en-PH", { month: "short", day: "numeric", year: "numeric" }).format(new Date(`${value}T12:00:00`))
  }
}
