import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["participant", "outcome"];
  static values = { driverId: Number };

  connect() {
    this.updateOutcomes();
  }

  updateOutcomes() {
    const driver = Number(this.participantTarget.value) === this.driverIdValue;
    for (const option of this.outcomeTarget.options) {
      const mismatched =
        (option.value === "driver_no_show" && !driver) ||
        (option.value === "passenger_no_show" && driver);
      option.disabled = mismatched;
      option.hidden = mismatched;
      if (mismatched && option.selected) this.outcomeTarget.value = "completed";
    }
  }
}
