import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["select", "detectButton"];

  connect() {
    // Auto-detect timezone on page load if field is empty
    if (this.hasSelectTarget && !this.selectTarget.value) {
      this.detectTimezone();
    }
  }

  detectTimezone() {
    // Get browser's timezone using Intl API
    try {
      const detectedTimezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
      
      if (!detectedTimezone) {
        console.warn("Timezone detection failed: timezone is undefined");
        return;
      }
      
      if (this.hasSelectTarget) {
        // Check if this is a hidden field (registration) or select field (profile edit)
        if (this.selectTarget.type === "hidden") {
          // For hidden fields, just set the value
          this.selectTarget.value = detectedTimezone;
        } else {
          // For select fields, find the matching option
          const options = Array.from(this.selectTarget.options);
          const matchingOption = options.find(opt => opt.value === detectedTimezone);
          
          if (matchingOption) {
            this.selectTarget.value = detectedTimezone;
            
            // Show a subtle indication that timezone was detected
            if (this.hasDetectButtonTarget) {
              this.showDetectedFeedback();
            }
          }
        }
      }
    } catch (error) {
      console.error("Error detecting timezone:", error);
    }
  }

  showDetectedFeedback() {
    const originalText = this.detectButtonTarget.textContent;
    this.detectButtonTarget.textContent = "✓ Detected";
    this.detectButtonTarget.classList.add("text-green-400");
    
    setTimeout(() => {
      this.detectButtonTarget.textContent = originalText;
      this.detectButtonTarget.classList.remove("text-green-400");
    }, 2000);
  }
}