import { Hono } from 'hono'
import { renderPage } from './render'

const app = new Hono()

// Pages live in notFound rather than app.get('*') so any route added to app
// wins over them, whatever the registration order.
app.notFound((c) => {
  if (c.req.method !== 'GET' && c.req.method !== 'HEAD') {
    return c.text('404 Not Found', 404)
  }
  const page = renderPage(new URL(c.req.url))
  return c.html(page.html, page.status)
})

export default app
