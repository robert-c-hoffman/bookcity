import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "status", "saveButton"]

  connect() {
    this.dirty = false
    this.saveTimeout = null
  }

  markDirty() {
    this.dirty = true
  }

  autoSave(event) {
    this.dirty = true

    // Clear any pending save
    if (this.saveTimeout) {
      clearTimeout(this.saveTimeout)
    }

    // Show saving indicator
    this.showStatus("Saving...")

    // Debounce the save - wait 500ms after last change
    this.saveTimeout = setTimeout(() => {
      this.submitForm()
    }, 500)
  }

  submitForm() {
    if (this.hasFormTarget) {
      this.formTarget.requestSubmit()
    }
  }

  showStatus(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
      this.statusTarget.classList.remove("hidden")
    }
  }

  hideStatus() {
    if (this.hasStatusTarget) {
      this.statusTarget.classList.add("hidden")
    }
  }
}
