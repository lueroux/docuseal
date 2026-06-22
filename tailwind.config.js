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
          primary: '#94be58',
          'primary-content': '#ffffff',
          secondary: '#6f8c46',
          'secondary-content': '#ffffff',
          accent: '#94be58',
          neutral: '#252525',
          'neutral-content': '#ffffff',
          'base-100': '#ececec',
          'base-200': '#e0e0e0',
          'base-300': '#d4d4d4',
          'base-content': '#252525',
          '--rounded-btn': '0.5rem',
          '--tab-border': '2px',
          '--tab-radius': '.5rem'
        }
      }
    ]
  }
}
