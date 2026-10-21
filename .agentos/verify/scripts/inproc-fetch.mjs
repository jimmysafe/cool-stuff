#!/usr/bin/env node
// Sandbox fallback driver: imports the Worker bundle produced by `wrangler deploy --dry-run`
// (the same module wrangler would upload) and calls its default export's fetch handler with a
// real Request, exactly as workerd would on an incoming HTTP request. Runs on Node, not workerd.
// usage: inproc-fetch.mjs <bundle/index.js> <METHOD> <path> [body]
// prints JSON {status, statusText, headers, body} on stdout.
import { pathToFileURL } from 'node:url'

const [bundle, method = 'GET', path = '/', body] = process.argv.slice(2)
if (!bundle) {
  console.error('usage: inproc-fetch.mjs <bundle/index.js> <METHOD> <path> [body]')
  process.exit(2)
}
const mod = await import(pathToFileURL(bundle).href)
const worker = mod.default
if (!worker || typeof worker.fetch !== 'function') {
  console.error('bundle default export has no fetch handler')
  process.exit(3)
}
const req = new Request(new URL(path, 'http://127.0.0.1'), {
  method,
  body: body === undefined || method === 'GET' || method === 'HEAD' ? undefined : body,
})
const ctx = { waitUntil() {}, passThroughOnException() {} }
let res = await worker.fetch(req, {}, ctx)
// workerd strips the body of HEAD responses on the wire; mirror that.
const text = method === 'HEAD' ? '' : await res.text()
console.log(JSON.stringify({
  status: res.status,
  statusText: res.statusText,
  headers: Object.fromEntries(res.headers),
  body: text,
}))
