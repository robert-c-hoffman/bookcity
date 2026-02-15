import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="pull-to-refresh"
export default class extends Controller {
  static values = {
    threshold: { type: Number, default: 60 }
  }

  // Constants for iOS-like behavior
  static RESISTANCE_FACTOR = 0.4  // Resistance when pulling (iOS-like feel)
  static MAX_PULL = 120  // Maximum pull distance before capping

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
    
    // Create iOS-style refresh indicator
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
    
    // Cancel any pending animation frames
    if (this.rafId) {
      cancelAnimationFrame(this.rafId)
    }
    
    // Clean up indicator
    if (this.indicator) {
      this.indicator.remove()
    }
    
    // Reset body styles
    document.body.style.transform = ''
    document.body.style.transition = ''
  }

  createIndicator() {
    // Reuse existing indicator if present
    this.indicator = document.querySelector(".ios-pull-refresh-indicator")
    
    if (!this.indicator) {
      this.indicator = document.createElement("div")
      this.indicator.className = "ios-pull-refresh-indicator"
      this.indicator.innerHTML = `
        <div class="ios-spinner"></div>
      `
      
      document.body.appendChild(this.indicator)
    }
    
    // Reset indicator state
    this.indicator.style.opacity = '0'
    this.indicator.style.transform = 'translateY(-100%)'
  }

  handleTouchStart(event) {
    // Only allow pull-to-refresh when at the top of the page
    if (window.scrollY === 0 && !this.refreshing && event.touches?.length > 0) {
      this.startY = event.touches[0].clientY
      this.pulling = false
    }
  }

  handleTouchMove(event) {
    if (this.refreshing || !event.touches?.length) return
    
    this.currentY = event.touches[0].clientY
    const pullDistance = this.currentY - this.startY
    
    // Only activate if pulling down from the top
    if (pullDistance > 0 && window.scrollY === 0) {
      this.pulling = true
      
      // Prevent default scrolling when pulling
      if (pullDistance > 10) {
        event.preventDefault()
      }
      
      // Apply iOS-like resistance and cap the pull distance
      const resistedPull = Math.min(
        pullDistance * this.constructor.RESISTANCE_FACTOR,
        this.constructor.MAX_PULL
      )
      
      // Use requestAnimationFrame to batch DOM updates for better performance
      if (!this.rafId) {
        this.rafId = requestAnimationFrame(() => {
          // Translate the body content down (iOS-style elastic pull)
          document.body.style.transform = `translateY(${resistedPull}px)`
          document.body.style.transition = 'none'
          
          // Show and animate the spinner
          const opacity = Math.min(resistedPull / this.thresholdValue, 1)
          this.indicator.style.opacity = opacity
          this.indicator.style.transform = `translateY(${resistedPull - 30}px)`
          this.indicator.style.transition = 'none'
          
          // Rotate spinner based on pull distance (iOS-like behavior)
          const spinner = this.indicator.querySelector('.ios-spinner')
          const rotation = (resistedPull / this.thresholdValue) * 360
          spinner.style.transform = `rotate(${rotation}deg)`
          
          this.rafId = null
        })
      }
    }
  }

  handleTouchEnd(event) {
    if (!this.pulling || this.refreshing) return
    
    const pullDistance = this.currentY - this.startY
    const resistedPull = Math.min(
      pullDistance * this.constructor.RESISTANCE_FACTOR,
      this.constructor.MAX_PULL
    )
    
    if (resistedPull >= this.thresholdValue) {
      this.refresh()
    } else {
      this.reset()
    }
    
    this.pulling = false
  }

  refresh() {
    this.refreshing = true
    
    // Keep spinner visible and animate it
    this.indicator.style.transition = 'all 0.2s ease-out'
    this.indicator.style.opacity = '1'
    this.indicator.style.transform = 'translateY(20px)'
    
    // Animate body back with a slight delay to show spinner
    document.body.style.transition = 'transform 0.2s ease-out'
    document.body.style.transform = 'translateY(0px)'
    
    // Start spinning animation
    const spinner = this.indicator.querySelector('.ios-spinner')
    spinner.classList.add('spinning')
    
    // Small delay to show the animation, then reload
    setTimeout(() => {
      window.location.reload()
    }, 200)
  }

  reset() {
    // Smoothly animate everything back to start position
    document.body.style.transition = 'transform 0.3s ease-out'
    document.body.style.transform = 'translateY(0px)'
    
    this.indicator.style.transition = 'opacity 0.3s ease-out, transform 0.3s ease-out'
    this.indicator.style.opacity = '0'
    this.indicator.style.transform = 'translateY(-100%)'
    
    const spinner = this.indicator.querySelector('.ios-spinner')
    spinner.style.transition = 'transform 0.3s ease-out'
    spinner.style.transform = 'rotate(0deg)'
  }
}
