import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'
import fs from 'node:fs'
import path from 'node:path'

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  // Load VITE_* variables from .env / .env.local for this mode
  const env = loadEnv(mode, process.cwd(), 'VITE_')

  // ── Generate FCM service worker from template ─────────────
  // The service worker can't read import.meta.env (it runs in a
  // separate worker context at a fixed path), so we substitute
  // placeholders at build/dev time from the same env file the
  // main bundle uses. Single source of truth: .env.local.
  generateFcmServiceWorker(env)

  return {
    plugins: [react()],
  }
})

function generateFcmServiceWorker(env) {
  const templatePath = path.resolve('firebase-messaging-sw.template.js')
  const outputPath   = path.resolve('public/firebase-messaging-sw.js')

  if (!fs.existsSync(templatePath)) {
    // Template missing — nothing to generate. This keeps lint/build
    // from failing if a contributor deletes the template by mistake.
    return
  }

  const keys = [
    'VITE_FIREBASE_API_KEY',
    'VITE_FIREBASE_AUTH_DOMAIN',
    'VITE_FIREBASE_PROJECT_ID',
    'VITE_FIREBASE_STORAGE_BUCKET',
    'VITE_FIREBASE_MESSAGING_SENDER_ID',
    'VITE_FIREBASE_APP_ID',
  ]

  let content = fs.readFileSync(templatePath, 'utf8')
  for (const key of keys) {
    content = content.replaceAll(`__${key}__`, env[key] ?? '')
  }

  fs.writeFileSync(outputPath, content)
}
