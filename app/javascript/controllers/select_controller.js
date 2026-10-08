import { Controller } from "@hotwired/stimulus";
import TomSelect from "tom-select";

export default class extends Controller {
  connect() {
    if (this.element.tomselect) return;

    this.select = new TomSelect(this.element, {
      maxOptions: null,
      closeAfterSelect: !this.element.multiple,
      allowEmptyOption: true,
      create: false,
      plugins: ["dropdown_input"]
    });
    // Tom Select hides the original select; label and error references belong on its visible input too.
    const control = this.select.control;
    for (const attribute of ["aria-invalid", "aria-describedby"]) {
      const value = this.element.getAttribute(attribute);
      if (value) {
        control.setAttribute(attribute, value);
        this.select.control_input.setAttribute(attribute, value);
      }
    }
    this.select.control_input.id = `${this.element.id}-ts-search`;
    if (control.getAttribute("aria-labelledby")) {
      this.select.control_input.setAttribute("aria-labelledby", control.getAttribute("aria-labelledby"));
    }
    this.element.closest("form")?.querySelectorAll(`a[href="#${this.element.id}"]`).forEach(link => {
      link.href = `#${control.id}`;
    });
    const label = this.element.closest(".form-field")?.querySelector("label");
    this.label = label;
    if (label) {
      label.htmlFor = control.id;
    }
  }

  disconnect() {
    this.teardown();
  }

  teardown() {
    // Morph the original select, not Tom Select's generated controls.
    if (this.select) {
      if (this.label) this.label.htmlFor = this.element.id;
      const value = this.select.getValue();
      this.select.destroy();
      for (const option of this.element.options) {
        option.selected = [value].flat().includes(option.value);
        option.toggleAttribute("selected", option.selected);
      }
      this.select = null;
    }
  }
}
