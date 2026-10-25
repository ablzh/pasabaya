import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input"];

  decrease() {
    this.change(-1);
  }

  increase() {
    this.change(1);
  }

  change(delta) {
    const value = this.inputTarget.valueAsNumber;
    this.inputTarget.value = Math.max(1, (Number.isInteger(value) ? value : 3) + delta);
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }));
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }));
  }
}
