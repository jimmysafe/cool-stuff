#!/usr/bin/env node
// Drives the Worker bundle in headless Chromium without a TCP server: page.route() answers every
// request to a fake origin the way Cloudflare would, static assets first, then the Worker's fetch.
// usage: browser-check.mjs <bundle/index.js> <assets-dir> <evidence-dir>
// env: PLAYWRIGHT_CORE (path to playwright-core, default: normal resolution), HEADLESS_SHELL (browser binary).
import { mkdirSync, readFileSync, statSync, writeFileSync } from 'node:fs'
import { extname, join, resolve, sep } from 'node:path'
import { pathToFileURL } from 'node:url'

const [bundle, assetsArg, evidenceArg] = process.argv.slice(2)
if (!bundle || !assetsArg || !evidenceArg) {
  console.error('usage: browser-check.mjs <bundle/index.js> <assets-dir> <evidence-dir>')
  process.exit(2)
}
const assetsDir = resolve(assetsArg)
const evidenceDir = resolve(evidenceArg)
mkdirSync(evidenceDir, { recursive: true })

const pwPath = process.env.PLAYWRIGHT_CORE
const { chromium } = await import(pwPath ? pathToFileURL(resolve(pwPath, 'index.mjs')).href : 'playwright-core')
const worker = (await import(pathToFileURL(resolve(bundle)).href)).default

const ORIGIN = 'http://cool-stuff.test'
const TYPES = {
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.css': 'text/css',
  '.html': 'text/html; charset=utf-8',
  '.json': 'application/json',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
  '.map': 'application/json',
}
const ctx = { waitUntil() {}, passThroughOnException() {} }

function assetFile(pathname) {
  const file = join(assetsDir, decodeURIComponent(pathname))
  if (!file.startsWith(assetsDir + sep)) return null
  try {
    return statSync(file).isFile() ? file : null
  } catch {
    return null
  }
}

const results = []
function record(ok, label, detail = '') {
  const line = `${ok ? 'PASS' : 'FAIL'} ${label}${!ok && detail ? ` (${detail})` : ''}`
  results.push(line)
  console.log(line)
  return ok
}
// fn passes by returning true or nothing; it fails by throwing, returning false, or returning a reason string.
async function check(label, fn) {
  try {
    const out = await fn()
    return record(out === true || out === undefined, label, typeof out === 'string' ? out : 'condition false')
  } catch (err) {
    return record(false, label, String(err.message ?? err).split('\n')[0])
  }
}

const browser = await chromium.launch({ executablePath: process.env.HEADLESS_SHELL, args: ['--single-process'] })
const page = await browser.newPage()
const pageErrors = []
const consoleErrors = []
const scriptResponses = []
let documentRequests = 0
page.on('pageerror', (err) => pageErrors.push(err.message))
// Chrome logs a network error for every 4xx document, so the deliberate /nope load is the one allowed entry.
const expectedConsoleError = (text, url) => url === `${ORIGIN}/nope` && text.includes('status of 404')
page.on('console', (msg) => {
  if (msg.type() !== 'error' || expectedConsoleError(msg.text(), msg.location().url)) return
  consoleErrors.push(`${msg.text()} @ ${msg.location().url}`)
})
page.on('request', (req) => req.resourceType() === 'document' && documentRequests++)
page.on('response', (res) => res.request().resourceType() === 'script' && scriptResponses.push(`${res.status()} ${res.url()}`))

await page.route('**/*', async (route) => {
  const req = route.request()
  const url = new URL(req.url())
  if (url.origin !== ORIGIN) return route.abort()
  const file = req.method() === 'GET' || req.method() === 'HEAD' ? assetFile(url.pathname) : null
  if (file) {
    return route.fulfill({
      status: 200,
      headers: { 'content-type': TYPES[extname(file)] ?? 'application/octet-stream' },
      body: readFileSync(file),
    })
  }
  const body = req.method() === 'GET' || req.method() === 'HEAD' ? undefined : req.postDataBuffer() ?? undefined
  const res = await worker.fetch(new Request(url, { method: req.method(), headers: req.headers(), body }), {}, ctx)
  return route.fulfill({
    status: res.status,
    headers: Object.fromEntries(res.headers),
    body: Buffer.from(await res.arrayBuffer()),
  })
})

const heading = (name) => page.getByRole('heading', { name, exact: true })
const link = (name) => page.getByRole('link', { name, exact: true })
const visible = async (locator) => {
  await locator.waitFor({ state: 'visible', timeout: 5000 })
}
const path = () => new URL(page.url()).pathname
const shot = (name) => page.screenshot({ path: join(evidenceDir, `${name}.png`), fullPage: true })

async function waitForHydration(label) {
  await check(`${label}: client script ran and React hydrated the page`, async () => {
    await page.waitForFunction(
      () =>
        typeof window.__reactRouterVersion === 'string' &&
        [...document.querySelectorAll('#root a')].every((a) => Object.keys(a).some((k) => k.startsWith('__reactFiber$'))),
      null,
      { timeout: 5000 },
    )
  })
  await page.evaluate(() => {
    window.__marker = 'same-document'
  })
}

async function clientNav(from, linkName, toPath, toHeading) {
  const before = documentRequests
  await check(`${from}: click ${linkName} goes to ${toPath}`, async () => {
    await link(linkName).click()
    await page.waitForURL((u) => u.pathname === toPath, { timeout: 5000 })
  })
  await check(`${toPath} after click: heading ${toHeading} visible`, () => visible(heading(toHeading)))
  await check(`${toPath} after click: window.__marker survived (same document)`, async () =>
    (await page.evaluate(() => window.__marker)) === 'same-document' || 'marker lost, the page reloaded',
  )
  await check(`${toPath} after click: no new document request`, () =>
    documentRequests === before || `document requests went from ${before} to ${documentRequests}`,
  )
}

let res = await page.goto(`${ORIGIN}/`)
await check('GET / responds 200', () => res.status() === 200 || `status ${res.status()}`)
await check('/: heading Home visible', () => visible(heading('Home')))
await check('/: link About visible', () => visible(link('About')))
await waitForHydration('/')
await check('/: /assets/client.js loaded with 200', () =>
  scriptResponses.includes(`200 ${ORIGIN}/assets/client.js`) || `script responses: ${scriptResponses.join(', ')}`,
)
await shot('home')
await clientNav('/', 'About', '/about', 'About')
await shot('home-to-about')
await clientNav('/about', 'Home', '/', 'Home')
await shot('about-to-home')

res = await page.goto(`${ORIGIN}/about`)
await check('GET /about directly responds 200', () => res.status() === 200 || `status ${res.status()}`)
await check('/about direct: heading About visible', () => visible(heading('About')))
await check('/about direct: link Home visible', () => visible(link('Home')))
await waitForHydration('/about direct')
await shot('about')
const beforeReload = documentRequests
res = await page.reload()
await check('/about reload responds 200', () => res.status() === 200 || `status ${res.status()}`)
await check('/about reload: one new document request and window.__marker cleared', async () =>
  (documentRequests === beforeReload + 1 && (await page.evaluate(() => window.__marker)) === undefined) ||
  `document requests ${beforeReload} -> ${documentRequests}`,
)
await check('/about reload: still on /about', () => path() === '/about' || `on ${path()}`)
await check('/about reload: heading About visible', () => visible(heading('About')))
await shot('about-reload')

res = await page.goto(`${ORIGIN}/nope`)
await check('GET /nope responds 404', () => res.status() === 404 || `status ${res.status()}`)
await check('/nope: heading Not found visible', () => visible(heading('Not found')))
await check('/nope: link Home visible', () => visible(link('Home')))
await waitForHydration('/nope')
await shot('not-found')
await clientNav('/nope', 'Home', '/', 'Home')
await shot('not-found-to-home')

record(pageErrors.length === 0, 'no page errors', pageErrors.join(' | '))
record(consoleErrors.length === 0, 'no console errors (hydration mismatches log here)', consoleErrors.join(' | '))

await browser.close()
writeFileSync(join(evidenceDir, 'browser-result.txt'), results.join('\n') + '\n')
const failed = results.filter((l) => l.startsWith('FAIL')).length
console.log(failed ? `browser-check: ${failed} FAIL, see ${evidenceDir}` : `browser-check: all ${results.length} PASS`)
process.exit(failed ? 1 : 0)
