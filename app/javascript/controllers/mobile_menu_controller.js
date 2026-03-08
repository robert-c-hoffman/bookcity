import { Controller } from "@hotwired/stimulus"

// Handles toggling the mobile navigation menu
// Connects to data-controller="mobile-menu"
export default class extends Controller {
  static targets = ["menu", "openIcon", "closeIcon"]

  toggle() {
    this.menuTarget.classList.toggle("hidden")
    if (this.hasOpenIconTarget) this.openIconTarget.classList.toggle("hidden")
    if (this.hasCloseIconTarget) this.closeIconTarget.classList.toggle("hidden")
  }

  close() {
    this.menuTarget.classList.add("hidden")
    if (this.hasOpenIconTarget) this.openIconTarget.classList.remove("hidden")
    if (this.hasCloseIconTarget) this.closeIconTarget.classList.add("hidden")
  }
}
