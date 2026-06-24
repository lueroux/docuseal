const DEFAULT_DURATION = 5000
const SLIDE_OUT_CLASS = 'animate-slide-out-right'

export default class FlashToast extends HTMLElement {
  connectedCallback () {
    this.dismiss = this.dismiss.bind(this)

    this.duration = Number(this.dataset.duration || DEFAULT_DURATION)
    this.alertElement = this.querySelector('.alert') || this
    this.dismissButtons = Array.from(this.querySelectorAll('[data-flash-toast-dismiss]'))

    this.dismissButtons.forEach((button) => {
      button.addEventListener('click', this.dismiss)
    })

    if (this.duration > 0) {
      this.dismissTimeout = window.setTimeout(this.dismiss, this.duration)
    }
  }

  disconnectedCallback () {
    this.dismissButtons?.forEach((button) => {
      button.removeEventListener('click', this.dismiss)
    })

    if (this.dismissTimeout) {
      window.clearTimeout(this.dismissTimeout)
    }
  }

  dismiss () {
    if (this.isDismissing) return
    this.isDismissing = true

    const target = this.alertElement || this

    if (target && !target.classList.contains(SLIDE_OUT_CLASS)) {
      target.classList.add(SLIDE_OUT_CLASS)
    }

    const handleAnimationEnd = () => {
      target?.removeEventListener('animationend', handleAnimationEnd)
      this.remove()
    }

    if (target) {
      target.addEventListener('animationend', handleAnimationEnd)
    } else {
      this.remove()
    }
  }
}
