import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.dirty = new Set()
  }

  record(event) {
    const control = event.target
    if (!this.editable(control) || control.matches(":disabled") || !control.id || !control.form) return

    if (control.type === "radio") {
      // Selecting a radio also unchecks its siblings without firing their change events.
      for (const sibling of control.form.elements) {
        if (sibling.type === "radio" && sibling.name === control.name) this.dirty.add(sibling)
      }
    } else {
      this.dirty.add(control)
    }
  }

  preserve(event) {
    const control = event.target
    const replacement = event.detail.newElement
    // Removed fields and server-imposed disabled/readonly states must still take effect.
    if (!this.dirty.has(control) || !replacement || !this.editable(replacement)) return
    if (replacement.id !== control.id || replacement.name !== control.name || replacement.type !== control.type) return
    if (["checkbox", "radio"].includes(control.type) && replacement.value !== control.value) return

    event.preventDefault()
  }

  submitted(event) {
    if (event.type === "turbo:submit-start") {
      this.clearForm(event.target)
    } else {
      queueMicrotask(() => {
        if (!event.defaultPrevented) this.clearForm(event.target)
      })
    }
  }

  reset(event) {
    queueMicrotask(() => {
      if (!event.defaultPrevented) this.clearForm(event.target)
    })
  }

  clearForm(form) {
    for (const control of this.dirty) {
      if (control.form === form) this.dirty.delete(control)
    }
  }

  refresh() {
    for (const control of this.dirty) {
      if (!this.element.contains(control) || !this.editable(control)) this.dirty.delete(control)
    }
    // Let UI controllers rebuild dependent visibility without replaying user input events.
    requestAnimationFrame(() => {
      this.element.dispatchEvent(new CustomEvent("morph-draft:restored", { bubbles: true }))
    })
  }

  editable(control) {
    // Parent fieldsets still morph; incoming client-mode fieldsets can be disabled
    // until their UI controller reconciles the preserved mode and toggle values.
    return control instanceof Element && control.matches("input, textarea, select") &&
      !control.matches("[disabled], [readonly], [type=hidden], [type=submit], [type=button], [type=reset], [type=file]")
  }
}
