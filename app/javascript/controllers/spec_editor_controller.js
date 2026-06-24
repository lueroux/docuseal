import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['container', 'template', 'row']

  add(event) {
    event.preventDefault()
    const template = this.templateTarget.innerHTML
    const timestamp = Date.now()
    const tempId = `new_${timestamp}`
    const html = template.replace(/NEW_KEY/g, tempId)
    this.containerTarget.insertAdjacentHTML('beforeend', html)
  }

  remove(event) {
    event.preventDefault()
    const row = event.target.closest('[data-spec-editor-target="row"]')
    if (row) {
      row.remove()
    }
  }
}
