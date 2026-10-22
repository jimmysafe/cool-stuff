// @vitest-environment happy-dom
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import app from '../src/index'

// Each test hydrates its own server page, so it needs a fresh React and a
// fresh client entry. `act` must come from that same React copy.
async function hydrateServerPage(path: string) {
  const html = await (await app.request(path)).text()
  const served = new DOMParser().parseFromString(html, 'text/html')
  document.body.innerHTML = served.getElementById('root')!.outerHTML
  history.replaceState(null, '', path)

  vi.resetModules()
  const { act } = await import('react')
  const serverHeading = document.querySelector('h1')
  await act(async () => {
    await import('../src/client')
  })
  return { act, serverHeading }
}

function click(link: Element) {
  return link.dispatchEvent(
    new MouseEvent('click', { bubbles: true, cancelable: true, button: 0 }),
  )
}

function linkNamed(name: string) {
  const link = [...document.querySelectorAll('a')].find((a) => a.textContent === name)
  expect(link, `link "${name}"`).toBeDefined()
  return link!
}

let consoleError: ReturnType<typeof vi.spyOn>

beforeEach(() => {
  ;(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true
  consoleError = vi.spyOn(console, 'error')
})

afterEach(() => {
  vi.restoreAllMocks()
})

describe('client navigation', () => {
  it('hydrates the server Homepage and moves between pages without a document load', async () => {
    const { act, serverHeading } = await hydrateServerPage('/')
    expect(document.querySelector('h1')).toBe(serverHeading)
    expect(serverHeading?.textContent).toBe('Homepage')

    let notCanceled = true
    await act(async () => {
      notCanceled = click(linkNamed('About'))
    })
    expect(notCanceled, 'About click default prevented').toBe(false)
    expect(location.pathname).toBe('/about')
    expect(document.querySelector('h1')?.textContent).toBe('About')

    await act(async () => {
      notCanceled = click(linkNamed('Homepage'))
    })
    expect(notCanceled, 'Homepage click default prevented').toBe(false)
    expect(location.pathname).toBe('/')
    expect(document.querySelector('h1')?.textContent).toBe('Homepage')

    expect(consoleError).not.toHaveBeenCalled()
  })

  it('hydrates the server Not found page', async () => {
    const { serverHeading } = await hydrateServerPage('/nope')
    expect(document.querySelector('h1')).toBe(serverHeading)
    expect(serverHeading?.textContent).toBe('Not found')
    expect(consoleError).not.toHaveBeenCalled()
  })
})
