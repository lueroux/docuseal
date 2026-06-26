module.exports = {
  plugins: [
    require('daisyui')
  ],
  theme: {
    extend: {
      colors: {
        brand: '#94be58',
        'brand-dark': '#6f8c46'
      }
    }
  },
  daisyui: {
    themes: [
      {
        buxtons: {
          'color-scheme': 'light',
          'color-base-100': 'oklch(100% 0 0)',
          'color-base-200': 'oklch(93% 0 0)',
          'color-base-300': 'oklch(86% 0 0)',
          'color-base-content': 'oklch(35.519% 0.032 262.988)',
          'color-primary': '#94be57',
          'color-primary-content': 'oklch(33.387% 0.04 162.24)',
          'color-secondary': '#6f8c46',
          'color-secondary-content': 'oklch(100% 0 0)',
          'color-accent': 'oklch(72.772% 0.149 33.2)',
          'color-accent-content': 'oklch(0% 0 0)',
          'color-neutral': 'oklch(37% 0.013 285.805)',
          'color-neutral-content': 'oklch(98.462% 0.001 247.838)',
          'color-info': '#94be57',
          'color-info-content': 'oklch(0% 0 0)',
          'color-success': 'oklch(64.8% 0.15 160)',
          'color-success-content': 'oklch(0% 0 0)',
          'color-warning': 'oklch(84.71% 0.199 83.87)',
          'color-warning-content': 'oklch(0% 0 0)',
          'color-error': 'oklch(71.76% 0.221 22.18)',
          'color-error-content': 'oklch(0% 0 0)',
          '--radius-selector': '1rem',
          '--radius-field': '0rem',
          '--radius-box': '0.5rem',
          '--size-selector': '0.25rem',
          '--size-field': '0.25rem',
          '--border': '1px',
          '--depth': '1',
          '--noise': '0'
        }
      }
    ]
  }
}
