import { renderToString } from 'react-dom/server'
import { createStaticHandler, createStaticRouter, StaticRouterProvider } from 'react-router'
import { routes } from './routes'

export const CLIENT_SCRIPT = '/assets/client.js'

const handler = createStaticHandler(routes)

export async function renderPage(request: Request): Promise<Response> {
  const context = await handler.query(request)
  if (context instanceof Response) return context

  const router = createStaticRouter(handler.dataRoutes, context)
  const app = renderToString(<StaticRouterProvider router={router} context={context} />)
  const html = `<!doctype html><html lang="en"><head><meta charset="utf-8"><title>cool-stuff</title><script type="module" src="${CLIENT_SCRIPT}"></script></head><body><div id="root">${app}</div></body></html>`
  return new Response(html, {
    status: context.statusCode,
    headers: { 'content-type': 'text/html; charset=utf-8' },
  })
}
