import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="pull-to-refresh"
export default class extends Controller {
  static values = {
    threshold: { type: Number, default: 80 }
  }

  connect() {
    // Only enable on touch devices
    if (!('ontouchstart' in window)) {
      return
    }

    this.startY = 0
    this.currentY = 0
    this.pulling = false
    // Reset refreshing flag in case we're reconnecting after a refresh
    this.refreshing = false
    
    // Create refresh indicator (reuse if it already exists)
    this.createIndicator()
    
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
    
    // Don't remove indicator as it may be used by other pages during Turbo navigation
  }

  createIndicator() {
    // Reuse existing indicator if present
    this.indicator = document.querySelector(".pull-to-refresh-indicator")
    
    if (!this.indicator) {
      this.indicator = document.createElement("div")
      this.indicator.className = "pull-to-refresh-indicator"
      this.indicator.innerHTML = `
        <div class="flex items-center justify-center gap-2 text-gray-400 transition-all duration-300">
          <svg class="refresh-icon w-5 h-5 transition-transform duration-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
          </svg>
          <span class="refresh-text text-sm font-medium">Pull to refresh</span>
        </div>
      `
      
      // Add styles
      this.indicator.style.cssText = `
        position: fixed;
        top: 0;
        left: 0;
        right: 0;
        height: 60px;
        display: flex;
        align-items: center;
        justify-content: center;
        transform: translateY(-60px);
        transition: transform 0.3s ease;
        z-index: 40;
        pointer-events: none;
      `
      
      document.body.appendChild(this.indicator)
    }
    
    // Reset indicator state
    this.reset()
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
      
      // Update indicator position
      const translateY = Math.min(pullDistance - 60, 0)
      this.indicator.style.transform = `translateY(${translateY}px)`
      
      // Rotate the refresh icon based on pull distance
      const rotation = Math.min((pullDistance / this.thresholdValue) * 180, 180)
      const icon = this.indicator.querySelector(".refresh-icon")
      icon.style.transform = `rotate(${rotation}deg)`
      
      // Update text based on threshold
      const text = this.indicator.querySelector(".refresh-text")
      if (pullDistance >= this.thresholdValue) {
        text.textContent = "Release to refresh"
        text.classList.add("text-blue-400")
        text.classList.remove("text-gray-400")
      } else {
        text.textContent = "Pull to refresh"
        text.classList.remove("text-blue-400")
        text.classList.add("text-gray-400")
      }
    }
  }

  handleTouchEnd(event) {
    if (!this.pulling || this.refreshing) return
    
    const pullDistance = this.currentY - this.startY
    
    if (pullDistance >= this.thresholdValue) {
      this.refresh()
    } else {
      this.reset()
    }
  }

  refresh() {
    this.refreshing = true
    
    // Show indicator in refreshing state
    this.indicator.style.transform = "translateY(0px)"
    const text = this.indicator.querySelector(".refresh-text")
    text.textContent = "Refreshing..."
    
    const icon = this.indicator.querySelector(".refresh-icon")
    icon.style.animation = "spin 1s linear infinite"
    
    // Use Turbo to reload the current page
    // Note: Turbo.visit is synchronous and will reload the page immediately
    // The controller will reconnect on the new page, and connect() will reset the state
    Turbo.visit(window.location.href, { action: "replace" })
  }

  reset() {
    if (!this.indicator) return
    
    this.pulling = false
    // Don't reset refreshing flag here - only reset it in connect() after page reload
    this.indicator.style.transform = "translateY(-60px)"
    
    const icon = this.indicator.querySelector(".refresh-icon")
    if (icon) {
      icon.style.transform = "rotate(0deg)"
      icon.style.animation = ""
    }
    
    const text = this.indicator.querySelector(".refresh-text")
    if (text) {
      text.textContent = "Pull to refresh"
      text.classList.remove("text-blue-400")
      text.classList.add("text-gray-400")
    }
  }
}
