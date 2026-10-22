import type { ReactElement } from 'react'
import { Link, matchRoutes, useRoutes, type RouteObject } from 'react-router'

function Home(): ReactElement {
  return (
    <main>
      <h1>Homepage</h1>
      <Link to="/about">About</Link>
    </main>
  )
}

function About(): ReactElement {
  return (
    <main>
      <h1>About</h1>
      <Link to="/">Homepage</Link>
    </main>
  )
}

function NotFound(): ReactElement {
  return (
    <main>
      <h1>Not found</h1>
      <Link to="/">Homepage</Link>
    </main>
  )
}

export const routes = [
  { path: '/', element: <Home /> },
  { path: '/about', element: <About /> },
] satisfies RouteObject[]

export function App(): ReactElement | null {
  return useRoutes([...routes, { path: '*', element: <NotFound /> }])
}

export function statusFor(pathname: string): 200 | 404 {
  return matchRoutes(routes, pathname) ? 200 : 404
}
