module.exports = {
  env: {
    browser: true,
    es2021: true,
    node: true,
  },
  parserOptions: {
    ecmaVersion: 'latest',
    sourceType: 'module',
    ecmaFeatures: {
      jsx: true,
    },
  },
  plugins: ['react'],
  rules: {
    'no-undef': 'error',
  },
  globals: {
    process: 'readonly',
    React: 'readonly',
  },
  ignorePatterns: ['dist/**', 'node_modules/**'],
};
