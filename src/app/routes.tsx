import { isRouteErrorResponse, Link, Outlet, useRouteError, type RouteObject } from 'react-router'

function Layout(): React.JSX.Element {
  return (
    <main>
      <Outlet />
    </main>
  )
}

function Home(): React.JSX.Element {
  return (
    <>
      <h1>Home</h1>
      <Link to="/about">About</Link>
    </>
  )
}

function About(): React.JSX.Element {
  return (
    <>
      <h1>About</h1>
      <Link to="/">Home</Link>
    </>
  )
}

function NotFound(): React.JSX.Element {
  const error = useRouteError()
  if (isRouteErrorResponse(error) && error.status === 404) {
    return (
      <main>
        <h1>Not found</h1>
        <Link to="/">Home</Link>
      </main>
    )
  }
  return (
    <main>
      <h1>Something went wrong</h1>
    </main>
  )
}

export const routes: RouteObject[] = [
  {
    path: '/',
    element: <Layout />,
    errorElement: <NotFound />,
    children: [
      { index: true, element: <Home /> },
      { path: 'about', element: <About /> },
    ],
  },
]
