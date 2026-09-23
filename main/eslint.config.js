import js from '@eslint/js'
import vue from 'eslint-plugin-vue'
import globals from 'globals'

// El linter no está aquí para discutir de estilo. Está para atrapar las cosas
// que `vite build` compila sin quejarse y que solo se descubren en producción:
// una variable mal escrita, un `await` que falta, un componente sin registrar,
// una `key` en un `v-for`.
//
// Por eso las reglas de formato (comillas, punto y coma, sangría) se dejan
// fuera a propósito: un linter que grita por una coma entrena a la gente a
// ignorarlo, y entonces tampoco ve el error de verdad.
export default [
  { ignores: ['dist/**', 'node_modules/**', 'src/data/mockData.js'] },

  js.configs.recommended,
  ...vue.configs['flat/recommended'],

  {
    files: ['**/*.{js,vue}'],
    languageOptions: {
      ecmaVersion: 2023,
      sourceType: 'module',
      globals: { ...globals.browser }
    },
    rules: {
      // --- Lo que de verdad rompe la tienda ---------------------------------
      'no-undef': 'error',
      'no-unused-vars': ['warn', { argsIgnorePattern: '^_', caughtErrors: 'none' }],

      'no-async-promise-executor': 'error',
      'no-promise-executor-return': 'error',

      // NOTA: `require-atomic-updates` se probó y se descartó. En un componente
      // Vue, `x.value = ... ` después de un `await` es el patrón normal —
      // limpiar el formulario cuando la base confirmó— y la regla marcaba las
      // trece veces que aparece, todas correctas. Una regla que solo produce
      // falsos positivos enseña a ignorar el linter.
      // El bug que sí hay que cazar (un `await` olvidado) necesita análisis de
      // tipos, que este proyecto no tiene. Por ahora lo cubre la convención de
      // CLAUDE.md §4 y la prueba de humo.

      // CLAUDE.md §4: nada de diálogos del navegador. El linter lo hace cumplir
      // en vez de dejarlo en una convención que nadie relee.
      'no-alert': 'error',

      'no-console': ['warn', { allow: ['warn', 'error'] }],
      'no-debugger': 'error',
      eqeqeq: ['error', 'smart'],

      // --- Vue --------------------------------------------------------------
      'vue/multi-word-component-names': 'off',   // Home.vue, Cart.vue: son vistas
      'vue/max-attributes-per-line': 'off',
      'vue/singleline-html-element-content-newline': 'off',
      'vue/html-self-closing': 'off',
      'vue/html-indent': 'off',
      'vue/html-closing-bracket-newline': 'off',
      'vue/attributes-order': 'off',
      'vue/first-attribute-linebreak': 'off',
      'vue/html-closing-bracket-spacing': 'off',
      'vue/multiline-html-element-content-newline': 'off',

      'vue/require-v-for-key': 'error',
      'vue/no-use-v-if-with-v-for': 'error',
      'vue/no-mutating-props': 'error',
      'vue/require-explicit-emits': 'error',
      'vue/no-unused-components': 'error'
    }
  },

  // Los scripts de node corren fuera del navegador.
  {
    files: ['scripts/**/*.mjs', 'vite.config.js', 'eslint.config.js'],
    languageOptions: { globals: { ...globals.node } },
    rules: { 'no-console': 'off' }
  },

  // `responsive.mjs` es de Node, pero lleva dentro la función que Playwright
  // evalúa DENTRO de la página: ahí sí existen `document` y `getComputedStyle`.
  // Sin esto el linter marcaría siete falsos `no-undef` en un archivo correcto.
  {
    files: ['scripts/responsive.mjs'],
    languageOptions: { globals: { ...globals.node, ...globals.browser } }
  }
]
