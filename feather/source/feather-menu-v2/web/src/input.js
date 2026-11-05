// Standard browser gamepads only; device-specific layouts are not guessed.
// https://developer.mozilla.org/en-US/docs/Web/API/Gamepad_API/Using_the_Gamepad_API
export function controls(root) {
  return [...root.querySelectorAll('[data-menu-control], .close')].filter((node) => !node.matches(':disabled') && !node.closest('[hidden]'))
}

export function routeInput(root, action) {
  if (!root) return
  const available = controls(root)
  let target = document.activeElement
  if (!root.contains(target)) { target = available[0]; target?.focus() }
  if (!target) return
  if (action === 'previous' || action === 'next') {
    const direction = action === 'previous' ? -1 : 1
    available[(available.indexOf(target) + direction + available.length) % available.length]?.focus()
    return
  }
  const key = { up: 'ArrowUp', down: 'ArrowDown', left: 'ArrowLeft', right: 'ArrowRight', accept: 'Enter', back: 'Escape' }[action]
  if (!key) return
  const event = new KeyboardEvent('keydown', { key, bubbles: true, cancelable: true })
  target.dispatchEvent(event)
  if (event.defaultPrevented) return
  if (action === 'accept') target.click()
  if (['left', 'right', 'up', 'down'].includes(action) && target.matches('input[type="range"], input[type="number"]')) {
    try { target[action === 'left' || action === 'down' ? 'stepDown' : 'stepUp']() } catch { return }
    target.dispatchEvent(new Event('input', { bubbles: true }))
    target.dispatchEvent(new Event('change', { bubbles: true }))
  }
  if (['left', 'right', 'up', 'down'].includes(action) && target.matches('input[type="radio"]')) {
    const radios = [...target.closest('fieldset').querySelectorAll('input')].filter((node) => !node.matches(':disabled'))
    const direction = action === 'left' || action === 'up' ? -1 : 1
    const next = radios[(radios.indexOf(target) + direction + radios.length) % radios.length]
    next?.focus(); next?.click()
  }
}

export function startGamepad(getRoot) {
  let frame, previous = new Set(), nextRepeat = 0, first = true
  const poll = (now) => {
    let pads = []
    try { pads = [...(navigator.getGamepads?.() || [])] } catch { /* unavailable in this host */ }
    const pad = pads.find((candidate) => candidate?.connected && candidate.mapping === 'standard')
    const pressed = new Set()
    const mappings = { 0: 'accept', 1: 'back', 4: 'previous', 5: 'next', 12: 'up', 13: 'down', 14: 'left', 15: 'right' }
    for (const [index, action] of Object.entries(mappings)) if (pad?.buttons[index]?.pressed) pressed.add(action)
    if ((pad?.axes[0] || 0) < -0.6) pressed.add('left')
    if ((pad?.axes[0] || 0) > 0.6) pressed.add('right')
    if ((pad?.axes[1] || 0) < -0.6) pressed.add('up')
    if ((pad?.axes[1] || 0) > 0.6) pressed.add('down')
    if (!first) for (const action of pressed) {
      const edge = !previous.has(action)
      if (edge || (['up', 'down', 'left', 'right'].includes(action) && now >= nextRepeat)) {
        routeInput(getRoot(), action)
        nextRepeat = now + (edge ? 350 : 120)
      }
    }
    first = false; previous = pressed
    frame = requestAnimationFrame(poll)
  }
  frame = requestAnimationFrame(poll)
  return () => cancelAnimationFrame(frame)
}
