import js from '@eslint/js'
import globals from 'globals'
import { defineConfig, globalIgnores } from 'eslint/config'

export default defineConfig([
  { files: ['**/*.{js,mjs,cjs}'], plugins: { js }, extends: ['js/recommended'] },
  { files: ['**/*.{js,mjs,cjs}'], languageOptions: { globals: globals.browser } },
  // `docs/` is git-excluded working material — plans, and the design bundles a designer
  // hands over, which carry whole prototypes built by other tools. CI never sees them
  // because they are not checked out there, so the offences they report are local-only
  // noise that makes a clean run look dirty.
  globalIgnores(['./docs', './node_modules', './public', './tmp', './vendor']),
])
