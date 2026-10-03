import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["instructions"];

  connect() {
    this.update();
  }

  update() {
    const requesting = this.element.elements.namedItem("ride_post[post_type]").value === "requesting";
    const labels = {
      departure_time: requesting ? "Preferred Departure (optional)" : "Departure Time (required to publish a ride offer)",
      expected_arrival_at: requesting ? "Preferred Arrival (optional)" : "Expected Arrival Time (optional)",
      seats: requesting ? "Seats needed" : "Seats available"
    };
    for (const [field, label] of Object.entries(labels)) {
      this.element.querySelector(`label[for="ride_post_${field}"]`).textContent = label;
    }
    this.instructionsTarget.textContent = requesting
      ? "Tell drivers how many seats you need. Leave preferred times blank for a flexible request. View profiles to discuss a ride; this post does not reserve a seat."
      : "Offer seats on your trip. Choose Save draft to save a private draft, or Publish ride. Publishing needs a future departure; arrival is optional. Passengers request seats for your approval.";
  }
}
