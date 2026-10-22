import { describe, expect, it } from 'vitest'
import app from '../src/index'

// Hono builds its matcher on the first request, so routes must be added first.
app.get('/api/ping', (c) => c.json({ ok: true }))

describe('worker pages', () => {
  it('serves the Homepage at /', async () => {
    const res = await app.request('/')
    expect(res.status).toBe(200)
    expect(res.headers.get('content-type')).toMatch(/text\/html/)
    const html = await res.text()
    expect(html).toContain('<h1>Homepage</h1>')
    expect(html).toMatch(/<a [^>]*href="\/about"[^>]*>About<\/a>/)
    expect(html).toContain('<script type="module" src="/client.js"></script>')
  })

  it.each(['/about', '/about?x=1'])('serves the About page at %s', async (path) => {
    const res = await app.request(path)
    expect(res.status).toBe(200)
    expect(res.headers.get('content-type')).toMatch(/text\/html/)
    const html = await res.text()
    expect(html).toContain('<h1>About</h1>')
    expect(html).toMatch(/<a [^>]*href="\/"[^>]*>Homepage<\/a>/)
  })

  it('answers HEAD /about', async () => {
    const res = await app.request('/about', { method: 'HEAD' })
    expect(res.status).toBe(200)
  })

  it('serves the Not found page with a 404 for an unknown path', async () => {
    const res = await app.request('/nope')
    expect(res.status).toBe(404)
    expect(res.headers.get('content-type')).toMatch(/text\/html/)
    expect(await res.text()).toContain('<h1>Not found</h1>')
  })

  it('keeps a plain 404 for methods other than GET and HEAD', async () => {
    const res = await app.request('/', { method: 'POST' })
    expect(res.status).toBe(404)
    expect(res.headers.get('content-type') ?? '').not.toMatch(/text\/html/)
  })

  it('lets a route registered after import win over the page fallback', async () => {
    const res = await app.request('/api/ping')
    expect(res.status).toBe(200)
    expect(await res.json()).toEqual({ ok: true })
  })
})
