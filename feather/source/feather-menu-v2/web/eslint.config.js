import js from '@eslint/js'
import pluginVue from 'eslint-plugin-vue'

export default [
  { ignores: ['dist/**', 'node_modules/**'] },
  js.configs.recommended,
  ...pluginVue.configs['flat/recommended'],
  {
    languageOptions: { ecmaVersion: 'latest', sourceType: 'module' },
    rules: {
      'vue/multi-word-component-names': 'off',
      'vue/max-attributes-per-line': 'off',
    },
  },
]

