import { Hono, type Context } from 'hono'
import { version } from '../package.json'

const binaryOp = (key: string, fn: (a: number, b: number) => number) => async (c: Context) => {
  let body
  try {
    body = await c.req.json()
  } catch {
    return c.json({ error: 'body must be valid JSON' }, 400)
  }
  const a = body?.a
  const b = body?.b
  if (!Number.isFinite(a) || !Number.isFinite(b)) {
    return c.json({ error: '"a" and "b" must be numbers' }, 400)
  }
  return c.json({ [key]: fn(a, b) })
}

const app = new Hono()

app.get('/', (c) => {
  return c.text('Hello Hono!')
})

app.get('/health', (c) => {
  return c.json({ status: 'ok', version })
})

app.post('/sum', binaryOp('sum', (a, b) => a + b))
app.post('/multiply', binaryOp('product', (a, b) => a * b))

export default app
