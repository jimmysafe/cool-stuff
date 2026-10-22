import { expect, it } from 'vitest'
import pkg from '../package.json'
import { CLIENT_SCRIPT } from '../src/render'

it('builds the client bundle where the page loads it from', () => {
  const outfile = /--outfile=(\S+)/.exec(pkg.scripts['build:client'])?.[1]
  expect(outfile).toBe(`dist/client${CLIENT_SCRIPT}`)
})
