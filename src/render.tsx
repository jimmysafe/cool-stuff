import { renderToString } from 'react-dom/server'
import { StaticRouter } from 'react-router'
import { App, statusFor } from './app'

export const CLIENT_SCRIPT = '/client.js'

export function renderPage(url: URL): { status: 200 | 404; html: string } {
  const body = renderToString(
    <StaticRouter location={url.pathname + url.search}>
      <App />
    </StaticRouter>,
  )
  // No whitespace inside #root: hydration compares it with the client render.
  const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>cool-stuff</title>
<script type="module" src="${CLIENT_SCRIPT}"></script>
</head>
<body>
<div id="root">${body}</div>
</body>
</html>`
  return { status: statusFor(url.pathname), html }
}
