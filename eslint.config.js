// ESLint 9 flat config — NOVA HUB V5 WEB
// Frontend sem bundler (IIFE + globais) + servidor Express (CommonJS).
'use strict';

const { defineConfig, globalIgnores } = require('eslint/config');

// Globais de navegador (DOM + timers + APIs web).
const browserGlobals = {
  // DOM / navegador
  window: 'readonly',
  document: 'readonly',
  navigator: 'readonly',
  location: 'readonly',
  localStorage: 'readonly',
  sessionStorage: 'readonly',
  history: 'readonly',
  customElements: 'readonly',
  requestAnimationFrame: 'readonly',
  cancelAnimationFrame: 'readonly',
  ResizeObserver: 'readonly',
  MutationObserver: 'readonly',
  WebSocket: 'readonly',
  AbortController: 'readonly',
  AbortSignal: 'readonly',
  fetch: 'readonly',
  alert: 'readonly',
  confirm: 'readonly',
  URL: 'readonly',
  URLSearchParams: 'readonly',
  FormData: 'readonly',
  CustomEvent: 'readonly',
  Event: 'readonly',
  KeyboardEvent: 'readonly',
  MouseEvent: 'readonly',
  PointerEvent: 'readonly',
  PerformanceObserver: 'readonly',
  matchMedia: 'readonly',
  getComputedStyle: 'readonly',
  HTMLElement: 'readonly',
  Element: 'readonly',
  Node: 'readonly',
  HTMLCanvasElement: 'readonly',
  FileReader: 'readonly',
  Blob: 'readonly',
  Image: 'readonly',
  performance: 'readonly',
  console: 'readonly',
  // Timers
  setTimeout: 'readonly',
  clearTimeout: 'readonly',
  setInterval: 'readonly',
  clearInterval: 'readonly',
  // Globais compartilhadas servidas pelo index.html (sem bundler/imports)
  Util: 'readonly',
  API: 'readonly',
  Auth: 'readonly',
  Router: 'readonly',
  TerminalModule: 'readonly',
  LinkModule: 'readonly',
  NexusModule: 'readonly',
  ArcadiaModule: 'readonly',
  CortexModule: 'readonly',
  SettingsModule: 'readonly',
};

const nodeServerGlobals = {
  require: 'readonly',
  module: 'readonly',
  exports: 'readonly',
  process: 'readonly',
  __dirname: 'readonly',
  __filename: 'readonly',
  console: 'readonly',
  Buffer: 'readonly',
  global: 'readonly',
  setInterval: 'readonly',
  setImmediate: 'readonly',
  setTimeout: 'readonly',
  clearInterval: 'readonly',
  clearImmediate: 'readonly',
  clearTimeout: 'readonly',
  URL: 'readonly',
  URLSearchParams: 'readonly',
  AbortSignal: 'readonly',
  AbortController: 'readonly',
  fetch: 'readonly',
};

// Testes Playwright: rodam em Node, mas usam `page.evaluate(fn)` cujo body
// executa no browser (document/window/getComputedStyle/Event) e expõem os
// módulos como globais. Por isso unimos Node + browser.
const testGlobals = { ...nodeServerGlobals, ...browserGlobals, describe: 'readonly', it: 'readonly', test: 'readonly', before: 'readonly', expect: 'readonly' };

const baseRules = {
  'no-unused-vars': ['error', { argsIgnorePattern: '^_', varsIgnorePattern: '^_' }],
  'no-undef': 'error',
  'no-eval': 'error',
  'no-implied-eval': 'error',
  'no-var': 'error',
  'prefer-const': 'warn',
  'no-console': 'off',
  'no-empty': ['error', { allowEmptyCatch: true }],
  'no-dupe-keys': 'error',
  'no-duplicate-case': 'error',
  'no-unreachable': 'error',
  'no-constant-condition': ['error', { checkLoops: false }],
  'no-fallthrough': 'error',
  'valid-typeof': 'error',
};

module.exports = defineConfig([
  globalIgnores(['node_modules/**', 'test-results/**', 'public/assets/**', '**/*.bak*', 'package-lock.json']),
  {
    files: ['server.js', 'terminal-server.js'],
    languageOptions: { ecmaVersion: 'latest', sourceType: 'commonjs', globals: { ...nodeServerGlobals } },
    rules: baseRules,
  },
  {
    files: ['tests/**/*.js'],
    languageOptions: { ecmaVersion: 'latest', sourceType: 'commonjs', globals: { ...testGlobals } },
    rules: baseRules,
  },
  {
    files: ['src/**/*.js'],
    languageOptions: { ecmaVersion: 'latest', sourceType: 'script', globals: { ...browserGlobals } },
    // no-unused-vars desligado em src: módulos são expostos como globais via
    // IIFE sem bundler (API, Auth, Router, LinkModule, ...), o que gera falsos
    // positivos. Mantemos as regras de erros reais (no-undef, no-eval, dupe, etc.).
    rules: { ...baseRules, 'no-unused-vars': 'off', 'no-undef': ['error', { typeof: false }] },
  },
]);
