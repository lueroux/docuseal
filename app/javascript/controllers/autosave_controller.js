import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['form', 'status']
  static values = {
    delay: { type: Number, default: 2000 }
  }

  connect() {
    this.timeout = null
    this.saving = false
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  save() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }

    this.timeout = setTimeout(() => {
      this.submitForm()
    }, this.delayValue)
  }

  async submitForm() {
    if (this.saving) return

    this.saving = true
    this.updateStatus('Saving...')

    const form = this.formTarget
    const formData = new FormData(form)

    try {
      const response = await fetch(form.action, {
        method: form.method || 'POST',
        body: formData,
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'application/json'
        }
      })

      if (response.ok) {
        this.updateStatus('Saved', 'success')
      } else {
        this.updateStatus('Error saving', 'error')
      }
    } catch (error) {
      console.error('Autosave error:', error)
      this.updateStatus('Error saving', 'error')
    } finally {
      this.saving = false
      setTimeout(() => {
        this.clearStatus()
      }, 3000)
    }
  }

  updateStatus(message, type = 'info') {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
      this.statusTarget.className = `autosave-status autosave-status-${type}`
    }
  }

  clearStatus() {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = ''
      this.statusTarget.className = 'autosave-status'
    }
  }
}
