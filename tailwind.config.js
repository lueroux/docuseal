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
          'base-100': '#ffffff',
          'base-200': '#f5f5f5',
          'base-300': '#ececec',
          'base-content': '#252525',
          '--rounded-btn': '0.5rem',
          '--tab-border': '2px',
          '--tab-radius': '.5rem'
        }
      }
    ]
  }
}
