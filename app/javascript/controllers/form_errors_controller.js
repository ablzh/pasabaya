import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.form = this.element.closest("form")
    this.correct = this.correct.bind(this)
    this.form?.addEventListener("input", this.correct)
    this.form?.addEventListener("change", this.correct)
    requestAnimationFrame(() => {
      if (this.element.isConnected) this.element.focus()
    })
  }

  disconnect() {
    this.form?.removeEventListener("input", this.correct)
    this.form?.removeEventListener("change", this.correct)
  }

  focusField(event) {
    const id = event.currentTarget.hash.slice(1)
    const input = document.getElementById(id)
    if (!input) return
    event.preventDefault()
    const control = input.tomselect?.control || input
    input.closest(".form-field, fieldset")?.scrollIntoView({ block: "center" })
    control.focus()
  }

  correct(event) {
    const input = event.target
    if (input.type === "radio" && input.name === "ride_post[departure_choice]" && input.value !== "exact_time") {
      const exactTime = this.form.querySelector("#ride_post_exact_departure_time")
      if (exactTime) this.clearField(exactTime)
    }
    if (input.type === "password" && !input.id.endsWith("_confirmation")) {
      const confirmation = this.form.querySelector(`#${input.id}_confirmation`)
      if (confirmation?.dataset.formErrorRule === "confirmation") this.correct({ target: confirmation })
    }
    const rule = input.dataset.formErrorRule
    const value = input.value?.trim() || ""
    const valid = rule === "required" ? value !== "" :
      rule === "accepted" ? input.checked :
      rule === "confirmation" ? value !== "" && input.value === this.form.querySelector(`#${input.id.replace(/_confirmation$/, "")}`)?.value :
      rule === "positive-integer" ? /^\d+$/.test(value) && Number(value) > 0 :
      rule === "max-length" ? Array.from(input.value).length <= Number(input.dataset.formErrorLimit) : false
    if (!valid || !input.validity.valid) return

    this.clearField(input)
  }

  clearField(input) {
    const fieldId = input.type === "radio" ? this.form.querySelector(`input[name="${input.name}"]`).id : input.id
    const errorId = input.type === "radio" ? "ride_post_departure_choice_error" : `${fieldId}_error`
    document.getElementById(errorId)?.remove()
    const controls = input.type === "radio" ? Array.from(input.closest("fieldset").querySelectorAll("input[type=radio]")).concat(input.closest("fieldset")) : [input, input.tomselect?.control, input.tomselect?.control_input].filter(Boolean)
    controls.forEach((control) => {
      control.removeAttribute("aria-invalid")
      const ids = (control.getAttribute("aria-describedby") || "").split(" ").filter((id) => id && id !== errorId)
      if (ids.length) control.setAttribute("aria-describedby", ids.join(" "))
      else control.removeAttribute("aria-describedby")
    })
    controls.forEach((control) => { delete control.dataset.formErrorRule })
    this.element.querySelectorAll("[data-error-for]").forEach((entry) => {
      if (entry.dataset.errorFor === fieldId) entry.remove()
    })
    // Keep server-only errors and other fields' corrections visible.
    if (!this.element.querySelector("li")) this.element.hidden = true
  }
}
