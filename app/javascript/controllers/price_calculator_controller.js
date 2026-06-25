import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['retailPrice', 'quotedPrice', 'discountPercentage', 'discountAmount', 'finalPrice', 'lineTotal', 'discountDisplay']
  static values = {
    retail: Number,
    optionsTotal: Number,
    quantity: Number
  }

  connect() {
    this.updateCalculations()
    this.updateLineTotal()
  }

  // Update the line total immediately without form submit
  updateLineTotal() {
    if (!this.hasLineTotalTarget) return
    const quotedPrice = parseFloat(this.quotedPriceTarget?.value) || 0
    const options = this.optionsTotalValue || 0
    const qty = this.quantityValue || 1
    const total = (quotedPrice + options) * qty
    this.lineTotalTarget.textContent = '£' + total.toLocaleString('en-GB', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
  }

  // When quoted price changes, calculate discount
  quotedPriceChanged() {
    const quotedPrice = parseFloat(this.quotedPriceTarget.value) || 0
    const retailPrice = this.retailValue || parseFloat(this.retailPriceTarget?.value) || 0
    
    if (retailPrice > 0) {
      const discountAmount = retailPrice - quotedPrice
      const discountPercentage = (discountAmount / retailPrice) * 100
      
      if (this.hasDiscountPercentageTarget) {
        this.discountPercentageTarget.value = Math.max(0, discountPercentage).toFixed(2)
      }
      
      if (this.hasDiscountAmountTarget) {
        this.discountAmountTarget.value = Math.max(0, discountAmount).toFixed(2)
      }
    }
    
    this.updateLineTotal()
    this.updateLineTotal()
    this.submitForm()
  }

  // When discount percentage changes, calculate quoted price
  discountPercentageChanged() {
    const discountPercentage = parseFloat(this.discountPercentageTarget.value) || 0
    const retailPrice = this.retailValue || parseFloat(this.retailPriceTarget?.value) || 0
    if (retailPrice > 0) {
      const discountAmount = (retailPrice * discountPercentage) / 100
      const quotedPrice = retailPrice - discountAmount
      if (this.hasQuotedPriceTarget) {
        this.quotedPriceTarget.value = Math.max(0, quotedPrice).toFixed(2)
      }
      if (this.hasDiscountAmountTarget) {
        this.discountAmountTarget.value = Math.max(0, discountAmount).toFixed(2)
      }
      if (this.hasFinalPriceTarget) {
        this.finalPriceTarget.textContent = Math.max(0, quotedPrice).toFixed(2)
      }
    }
    this.updateLineTotal()
    this.submitForm()
  }

  // When discount amount changes, calculate quoted price and percentage
  discountAmountChanged() {
    const discountAmount = parseFloat(this.discountAmountTarget.value) || 0
    const retailPrice = this.retailValue || parseFloat(this.retailPriceTarget?.value) || 0
    if (retailPrice > 0) {
      const quotedPrice = retailPrice - discountAmount
      const discountPercentage = (discountAmount / retailPrice) * 100
      if (this.hasQuotedPriceTarget) {
        this.quotedPriceTarget.value = Math.max(0, quotedPrice).toFixed(2)
      }
      if (this.hasDiscountPercentageTarget) {
        this.discountPercentageTarget.value = Math.max(0, discountPercentage).toFixed(2)
      }
      if (this.hasFinalPriceTarget) {
        this.finalPriceTarget.textContent = Math.max(0, quotedPrice).toFixed(2)
      }
    }
    this.updateLineTotal()
    this.submitForm()
  }

  updateCalculations() {
    const quotedPrice = parseFloat(this.quotedPriceTarget?.value) || 0
    const retailPrice = this.retailValue || parseFloat(this.retailPriceTarget?.value) || 0
    if (retailPrice > 0 && quotedPrice > 0) {
      const discountAmount = retailPrice - quotedPrice
      const discountPercentage = (discountAmount / retailPrice) * 100
      if (this.hasDiscountPercentageTarget && !this.discountPercentageTarget.value) {
        this.discountPercentageTarget.value = Math.max(0, discountPercentage).toFixed(2)
      }
      if (this.hasDiscountAmountTarget && !this.discountAmountTarget.value) {
        this.discountAmountTarget.value = Math.max(0, discountAmount).toFixed(2)
      }
    }
    this.updateLineTotal()
  }

  submitForm() {
    // Debounce form submission
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      const form = this.element.closest('form')
      if (form && form.requestSubmit) {
        form.requestSubmit()
      }
    }, 500)
  }
}
