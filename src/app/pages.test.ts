import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import app from '../index'
import { CLIENT_SCRIPT } from './server'

async function get(path: string, init?: RequestInit) {
  const res = await app.request(path, init)
  return { status: res.status, type: res.headers.get('content-type') ?? '', body: await res.text() }
}

describe('Worker page responses', () => {
  it('serves the homepage', async () => {
    const res = await get('/')
    expect(res.status).toBe(200)
    expect(res.type).toContain('text/html')
    expect(res.body).toContain('<h1>Home</h1>')
    expect(res.body).toContain('href="/about"')
  })

  it('serves the about page on a direct load', async () => {
    const res = await get('/about')
    expect(res.status).toBe(200)
    expect(res.type).toContain('text/html')
    expect(res.body).toContain('<h1>About</h1>')
    expect(res.body).toContain('href="/"')
  })

  it('serves the not found page with a 404 for an unknown URL', async () => {
    const res = await get('/nope')
    expect(res.status).toBe(404)
    expect(res.type).toContain('text/html')
    expect(res.body).toContain('Not found')
    expect(res.body).toContain('href="/"')
  })

  it('does not render pages for non-GET requests', async () => {
    const res = await get('/', { method: 'POST' })
    expect(res.status).toBe(404)
    expect(res.type).not.toContain('text/html')
  })

  it('loads the client bundle from where build:client writes it', () => {
    const pkg = JSON.parse(readFileSync(new URL('../../package.json', import.meta.url), 'utf8'))
    const outfile = /--outfile=(\S+)/.exec(pkg.scripts['build:client'])?.[1]
    expect(outfile?.endsWith(CLIENT_SCRIPT)).toBe(true)
  })
})
