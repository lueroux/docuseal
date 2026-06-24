export default class extends HTMLElement {
  connectedCallback() {
    this.container = this.querySelector('[data-container]')
    this.template = this.querySelector('[data-template]')
    this.addButton = this.querySelector('[data-add]')

    if (this.addButton) {
      this.addButton.addEventListener('click', (e) => this.addRow(e))
    }

    this.querySelectorAll('[data-remove]').forEach(btn => {
      btn.addEventListener('click', (e) => this.removeRow(e))
    })
  }

  addRow(event) {
    event.preventDefault()
    if (!this.template) return

    const timestamp = Date.now()
    const tempId = `new_${timestamp}`
    const html = this.template.innerHTML.replace(/NEW_KEY/g, tempId)
    this.container.insertAdjacentHTML('beforeend', html)

    const newRow = this.container.lastElementChild
    if (newRow) {
      const removeBtn = newRow.querySelector('[data-remove]')
      if (removeBtn) {
        removeBtn.addEventListener('click', (e) => this.removeRow(e))
      }
    }
  }

  removeRow(event) {
    event.preventDefault()
    const row = event.target.closest('[data-row]')
    if (row) {
      row.remove()
    }
  }
}
