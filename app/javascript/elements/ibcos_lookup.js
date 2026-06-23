export default class extends HTMLElement {
  connectedCallback() {
    this.button = this.querySelector('[data-button]')
    this.skuField = this.querySelector('[data-sku]')
    this.statusDiv = this.querySelector('[data-status]')
    
    if (this.button) {
      this.button.addEventListener('click', () => this.fetch())
    }
  }

  async fetch() {
    const sku = this.skuField?.value?.trim()
    
    if (!sku) {
      this.setStatus('Please enter a SKU first', 'error')
      return
    }

    this.setLoading(true)
    this.setStatus('Searching IBCOS...', 'info')

    try {
      const response = await fetch(`/ibcos/quick?part_no=${encodeURIComponent(sku)}`, {
        headers: {
          'Accept': 'application/json'
        }
      })

      const data = await response.json()

      if (data.found && data.product) {
        this.populateFields(data.product)
        this.setStatus('Product found and populated!', 'success')
      } else {
        this.setStatus('Product not found in IBCOS', 'error')
      }
    } catch (error) {
      console.error('IBCOS lookup error:', error)
      this.setStatus('Error searching IBCOS', 'error')
    } finally {
      this.setLoading(false)
    }
  }

  populateFields(product) {
    const nameField = document.getElementById('product_name')
    const brandField = document.getElementById('product_brand')
    const categoryField = document.getElementById('product_category')
    const retailPriceField = document.getElementById('product_retail_price')
    const costPriceField = document.getElementById('product_cost_price')
    const descriptionField = document.getElementById('product_description')

    if (nameField && product.name) nameField.value = product.name
    if (brandField && product.brand) brandField.value = product.brand
    if (categoryField && product.category) categoryField.value = product.category
    if (retailPriceField && product.retail_price) retailPriceField.value = product.retail_price
    if (costPriceField && product.cost_price) costPriceField.value = product.cost_price
    if (descriptionField && product.description) descriptionField.value = product.description
  }

  setLoading(loading) {
    if (this.button) {
      this.button.disabled = loading
      this.button.innerHTML = loading
        ? '<span class="loading loading-spinner"></span> Searching...'
        : `<svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg> Search IBCOS`
    }
  }

  setStatus(message, type = 'info') {
    if (this.statusDiv) {
      this.statusDiv.textContent = message
      this.statusDiv.className = `text-sm mt-1 text-${type === 'error' ? 'error' : type === 'success' ? 'success' : 'info'}`
    }
  }
}
