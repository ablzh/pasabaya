import { Controller } from "@hotwired/stimulus";
import TomSelect from "tom-select";

export default class extends Controller {
  connect() {
    if (this.element.tomselect) return;

    this.select = new TomSelect(this.element, {
      maxOptions: null,
      closeAfterSelect: !this.element.multiple,
      allowEmptyOption: true,
      create: false
    });
  }

  disconnect() {
    if (this.select) {
      this.select.destroy();
      this.select = null;
    }
  }
}
