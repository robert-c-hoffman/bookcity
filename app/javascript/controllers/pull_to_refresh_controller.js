import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="pull-to-refresh"
export default class extends Controller {
  static values = {
    threshold: { type: Number, default: 80 }
  }

  connect() {
    // Only enable on iOS in standalone mode (when added to home screen)
    // @ts-ignore - standalone is a non-standard property that only exists on iOS
    const isInWebAppiOS = window.navigator.standalone === true
    
    if (!isInWebAppiOS) {
      return
    }

    // Only enable on touch devices
    if (!('ontouchstart' in window)) {
      return
    }

    this.startY = 0
    this.currentY = 0
    this.pulling = false
    this.refreshing = false
    
    // Bind touch event listeners
    this.boundTouchStart = this.handleTouchStart.bind(this)
    this.boundTouchMove = this.handleTouchMove.bind(this)
    this.boundTouchEnd = this.handleTouchEnd.bind(this)
    
    this.element.addEventListener("touchstart", this.boundTouchStart, { passive: true })
    this.element.addEventListener("touchmove", this.boundTouchMove, { passive: false })
    this.element.addEventListener("touchend", this.boundTouchEnd)
  }

  disconnect() {
    if (this.boundTouchStart) {
      this.element.removeEventListener("touchstart", this.boundTouchStart)
      this.element.removeEventListener("touchmove", this.boundTouchMove)
      this.element.removeEventListener("touchend", this.boundTouchEnd)
    }
  }

  handleTouchStart(event) {
    // Only allow pull-to-refresh when at the top of the page
    if (window.scrollY === 0 && !this.refreshing) {
      this.startY = event.touches[0].clientY
      this.pulling = false
    }
  }

  handleTouchMove(event) {
    if (this.refreshing) return
    
    this.currentY = event.touches[0].clientY
    const pullDistance = this.currentY - this.startY
    
    // Only activate if pulling down from the top
    if (pullDistance > 0 && window.scrollY === 0) {
      this.pulling = true
      
      // Prevent default scrolling when pulling
      if (pullDistance > 10) {
        event.preventDefault()
      }
    }
  }

  handleTouchEnd(event) {
    if (!this.pulling || this.refreshing) return
    
    const pullDistance = this.currentY - this.startY
    
    if (pullDistance >= this.thresholdValue) {
      this.refresh()
    }
    
    this.pulling = false
  }

  refresh() {
    this.refreshing = true
    // Reload the page
    window.location.reload()
  }
}
