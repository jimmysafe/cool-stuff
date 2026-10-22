import { hydrateRoot } from 'react-dom/client'
import { createBrowserRouter } from 'react-router'
import { RouterProvider } from 'react-router/dom'
import { routes } from './routes'

hydrateRoot(document.getElementById('root')!, <RouterProvider router={createBrowserRouter(routes)} />)
