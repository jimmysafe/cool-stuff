import { Hono } from 'hono'
import { version } from '../package.json'

const app = new Hono()

app.get('/', (c) => {
  return c.text('Hello Hono!')
})

app.get('/health', (c) => {
  return c.json({ status: 'ok', version })
})

export default app
