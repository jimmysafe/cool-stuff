import { hydrateRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router'
import { App } from './app'

hydrateRoot(
  document.getElementById('root')!,
  <BrowserRouter>
    <App />
  </BrowserRouter>,
)
