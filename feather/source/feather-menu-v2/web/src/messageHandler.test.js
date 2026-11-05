import { beforeEach, describe, expect, it, vi } from 'vitest'
import { post } from './api'
import { processMessage, resetMessageRecovery } from './messageHandler'
import { state } from './store'

vi.mock('./api', () => ({ post: vi.fn(() => Promise.resolve({ ok: true })) }))

const snapshot = (revision = 1) => ({
  action: 'menu:sync', menu: {
    menuId: 'owner:menu', revision, config: {}, activePageId: 'page', open: true, navigation: null,
    pages: [{ pageId: 'page', key: 'page', config: {}, elements: [] }],
  },
})

describe('NUI message recovery', () => {
  beforeEach(() => {
    state.menus = {}; state.activeMenuId = null
    resetMessageRecovery(); vi.clearAllMocks()
  })

  it('requests one bounded resync for repeated rejected patches', () => {
    processMessage(snapshot())
    const stale = { action: 'menu:patch', menuId: 'owner:menu', revision: 3, operations: [] }
    expect(processMessage(stale)).toBe(false)
    expect(processMessage(stale)).toBe(false)
    expect(post.mock.calls.filter(([endpoint]) => endpoint === 'desync')).toHaveLength(1)
    expect(post).toHaveBeenCalledWith('desync', { menuId: 'owner:menu' })
  })

  it('allows another recovery request after a full sync', () => {
    processMessage(snapshot())
    processMessage({ action: 'menu:patch', menuId: 'owner:menu', revision: 3, operations: [] })
    processMessage(snapshot(2))
    processMessage({ action: 'menu:patch', menuId: 'owner:menu', revision: 4, operations: [] })
    expect(post.mock.calls.filter(([endpoint]) => endpoint === 'desync')).toHaveLength(2)
  })

  it('acknowledges applied snapshots and patches, never rejected revisions', () => {
    processMessage(snapshot())
    expect(post).toHaveBeenLastCalledWith('ack', { menuId: 'owner:menu', revision: 1 })
    processMessage({ action: 'menu:patch', menuId: 'owner:menu', revision: 2, operations: [] })
    expect(post).toHaveBeenLastCalledWith('ack', { menuId: 'owner:menu', revision: 2 })
    processMessage(snapshot(1))
    expect(state.menus['owner:menu'].revision).toBe(2)
    expect(post.mock.calls.filter(([endpoint]) => endpoint === 'ack')).toHaveLength(2)
  })
})
