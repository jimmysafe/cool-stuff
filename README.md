# cool-stuff

A Cloudflare Worker that serves a React app. The Worker renders each page on
the server with React Router, and a small client bundle hydrates it so links
navigate without reloading the page.

## Quickstart

```sh
pnpm install
pnpm dev          # wrangler dev, builds the client bundle first
pnpm run check    # typecheck and tests
```

## Adding a page

Add one entry to `routes` in `src/app.tsx`:

```tsx
{ path: '/contact', element: <Contact /> },
```

Link to it with `<Link to="/contact">` from `react-router`, not a plain
`<a>`, so the navigation stays on the client. Paths outside `routes` show the
Not found page with a 404 status.
