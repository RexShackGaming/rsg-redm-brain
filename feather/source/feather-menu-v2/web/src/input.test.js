import { afterEach, describe, expect, it, vi } from 'vitest'
import { routeInput, startGamepad } from './input'

afterEach(() => { document.body.innerHTML = ''; vi.unstubAllGlobals() })

describe('controller routing', () => {
  it('moves through enabled controls, activates, and respects owned keys', () => {
    document.body.innerHTML = '<section><button data-menu-control>One</button><fieldset disabled><input data-menu-control></fieldset><button data-menu-control>Two</button></section>'
    const root = document.querySelector('section'), buttons = root.querySelectorAll('button')
    buttons[0].focus()
    routeInput(root, 'next')
    expect(document.activeElement).toBe(buttons[1])
    const clicked = vi.fn(); buttons[1].onclick = clicked
    routeInput(root, 'accept'); expect(clicked).toHaveBeenCalledTimes(1)
    buttons[1].onkeydown = (event) => event.preventDefault()
    routeInput(root, 'accept'); expect(clicked).toHaveBeenCalledTimes(1)
    routeInput(root, 'next'); expect(document.activeElement).toBe(buttons[0])
  })

  it('adjusts native range values and emits input', () => {
    document.body.innerHTML = '<section><input data-menu-control type="range" min="0" max="10" step="2" value="4"></section>'
    const root = document.querySelector('section'), input = root.querySelector('input')
    input.focus(); const change = vi.fn(); input.oninput = change
    routeInput(root, 'right')
    expect(input.value).toBe('6'); expect(change).toHaveBeenCalledTimes(1)
  })

  it('ignores held accept on mount and stops polling on cleanup', () => {
    let frame
    vi.stubGlobal('requestAnimationFrame', vi.fn((callback) => { frame = callback; return 7 }))
    vi.stubGlobal('cancelAnimationFrame', vi.fn())
    const pad = { connected: true, mapping: 'standard', buttons: [{ pressed: true }], axes: [0, 0] }
    vi.stubGlobal('navigator', { getGamepads: () => [pad] })
    document.body.innerHTML = '<section><button data-menu-control>Accept</button></section>'
    const root = document.querySelector('section'), clicked = vi.fn()
    root.querySelector('button').onclick = clicked
    const stop = startGamepad(() => root)
    frame(0); frame(1000); expect(clicked).not.toHaveBeenCalled()
    pad.buttons[0].pressed = false; frame(1100)
    pad.buttons[0].pressed = true; frame(1200); expect(clicked).toHaveBeenCalledTimes(1)
    stop(); expect(cancelAnimationFrame).toHaveBeenCalledWith(7)
  })
})
