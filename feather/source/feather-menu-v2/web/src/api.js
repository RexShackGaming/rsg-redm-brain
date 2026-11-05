const resourceName = typeof globalThis.GetParentResourceName === 'function'
  ? globalThis.GetParentResourceName()
  : 'feather-menu-v2'

export async function post(endpoint, payload = {}) {
  if (typeof globalThis.GetParentResourceName !== 'function') {
    if (import.meta.env.DEV) {
      const { simulateDevelopmentAction } = await import('./devFixture')
      return simulateDevelopmentAction(endpoint, payload)
    }
    return { ok: true }
  }
  try {
    const response = await fetch(`https://${resourceName}/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(payload),
    })
    return await response.json()
  } catch {
    return { ok: false, code: 'transport_unavailable' }
  }
}
