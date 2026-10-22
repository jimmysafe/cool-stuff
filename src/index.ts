import { Hono } from 'hono'
import { renderPage } from './app/server'

const app = new Hono()

// API routes go here, before the catch-all page route.
app.get('*', (c) => renderPage(c.req.raw))

export default app
