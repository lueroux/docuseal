const path = require('path')

module.exports = {
  content: [
    path.resolve(__dirname, 'app/javascript/template_builder/dynamic_area.vue'),
    path.resolve(__dirname, 'app/javascript/template_builder/dynamic_section.vue')
  ],
  theme: {
    extend: {
      colors: {
        'base-100': '#ececec',
        'base-200': '#e0e0e0',
        'base-300': '#d4d4d4',
        'base-content': '#252525'
      }
    }
  }
}
