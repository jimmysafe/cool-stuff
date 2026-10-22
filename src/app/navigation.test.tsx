// @vitest-environment jsdom
import { afterEach, describe, expect, it } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { createMemoryRouter, RouterProvider } from 'react-router'
import { routes } from './routes'

afterEach(cleanup)

describe('client-side navigation', () => {
  it('moves between Home and About without a document load', async () => {
    render(<RouterProvider router={createMemoryRouter(routes)} />)
    expect(screen.getByRole('heading', { name: 'Home' })).toBeTruthy()

    expect(fireEvent.click(screen.getByRole('link', { name: 'About' }))).toBe(false)
    expect(await screen.findByRole('heading', { name: 'About' })).toBeTruthy()

    expect(fireEvent.click(screen.getByRole('link', { name: 'Home' }))).toBe(false)
    expect(await screen.findByRole('heading', { name: 'Home' })).toBeTruthy()
  })

  it('shows the not found page for an unknown URL', () => {
    render(<RouterProvider router={createMemoryRouter(routes, { initialEntries: ['/nope'] })} />)
    expect(screen.getByRole('heading', { name: 'Not found' })).toBeTruthy()
    expect(screen.getByRole('link', { name: 'Home' })).toBeTruthy()
  })
})
