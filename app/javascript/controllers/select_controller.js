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
  }

  disconnect() {
    this.teardown();
  }

  teardown() {
    // Morph the original select, not Tom Select's generated controls.
    if (this.select) {
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
