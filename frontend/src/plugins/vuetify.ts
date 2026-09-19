import 'vuetify/styles'
import '@mdi/font/css/materialdesignicons.css'
import { createVuetify } from 'vuetify'

export default createVuetify({
  theme: {
    defaultTheme: 'studioDark',
    themes: {
      studioDark: {
        dark: true,
        colors: {
          background: '#10131a', surface: '#181d27', primary: '#8be8c4',
          secondary: '#e9b872', accent: '#98b7ff', error: '#ff7f87',
        },
      },
    },
  },
})
