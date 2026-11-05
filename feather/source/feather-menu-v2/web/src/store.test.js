import { beforeEach, describe, expect, it } from 'vitest'
import { handleMessage, patchMenu, state, syncMenu } from './store'

const snapshot = () => ({ menuId: 'owner:test', revision: 1, config: {}, activePageId: 'p', open: true, navigation: null, pages: [{ pageId: 'p', key: 'p', config: {}, elements: [{ elementId: 'e', type: 'button', data: { label: 'Old' } }] }] })

describe('menu store', () => {
  beforeEach(() => { state.menus = {}; state.activeMenuId = null })
  it('syncs a complete menu snapshot', () => { syncMenu(snapshot()); expect(state.menus['owner:test'].pages.p.elements.e.data.label).toBe('Old') })
  it('normalizes a Cfx-encoded empty Lua key table', () => {
    const value = snapshot(); value.keys = []
    expect(syncMenu(value)).toBe(true)
    expect(state.menus['owner:test'].keys).toEqual({})
  })
  it('reactively patches an element without replacing its identity', () => {
    syncMenu(snapshot()); const element = state.menus['owner:test'].pages.p.elements.e
    expect(patchMenu({ menuId: 'owner:test', revision: 2, operations: [{ op: 'element:update', pageId: 'p', elementId: 'e', changes: { label: 'Nuevo' } }] })).toBe(true)
    expect(state.menus['owner:test'].pages.p.elements.e).toBe(element); expect(element.data.label).toBe('Nuevo')
  })
  it('rejects a revision gap', () => { syncMenu(snapshot()); expect(patchMenu({ menuId: 'owner:test', revision: 3, operations: [] })).toBe(false) })
  it('adds and removes active-page elements reactively', () => {
    syncMenu(snapshot()); patchMenu({ menuId: 'owner:test', revision: 2, operations: [{ op: 'element:add', pageId: 'p', element: { elementId: 'new', type: 'textdisplay', data: { value: 'Hi' } } }] })
    expect(state.menus['owner:test'].pages.p.elementOrder).toContain('new')
    patchMenu({ menuId: 'owner:test', revision: 3, operations: [{ op: 'element:remove', pageId: 'p', elementId: 'new' }] })
    expect(state.menus['owner:test'].pages.p.elementOrder).not.toContain('new')
  })
  it('closes without deleting registered menu state', () => { syncMenu(snapshot()); handleMessage({ action: 'menu:close', menuId: 'owner:test' }); expect(state.menus['owner:test'].open).toBe(false) })
  it('rejects lifecycle messages for unknown menus', () => {
    expect(handleMessage({ action: 'menu:open', menuId: 'missing' })).toBe(false)
    expect(state.activeMenuId).toBeNull()
  })
  it('rejects malformed snapshots without mutating state', () => {
    expect(syncMenu({ menuId: 'bad', revision: 1 })).toBe(false)
    expect(state.menus.bad).toBeUndefined()
  })
  it('rejects snapshots with missing nested config or an unknown active page', () => {
    const missingConfig = snapshot(); delete missingConfig.pages[0].config
    expect(syncMenu(missingConfig)).toBe(false)
    const unknownActivePage = snapshot(); unknownActivePage.activePageId = 'missing'
    expect(syncMenu(unknownActivePage)).toBe(false)
  })
  it('rejects duplicate page and element ids in snapshots', () => {
    const duplicatePage = snapshot(); duplicatePage.pages.push({ ...duplicatePage.pages[0] })
    expect(syncMenu(duplicatePage)).toBe(false)
    const duplicateElement = snapshot(); duplicateElement.pages[0].elements.push({ ...duplicateElement.pages[0].elements[0] })
    expect(syncMenu(duplicateElement)).toBe(false)
  })
  it('rejects unknown operations atomically', () => {
    syncMenu(snapshot())
    expect(patchMenu({ menuId: 'owner:test', revision: 2, operations: [
      { op: 'element:update', pageId: 'p', elementId: 'e', changes: { label: 'Should not apply' } },
      { op: 'unknown' },
    ] })).toBe(false)
    expect(state.menus['owner:test'].pages.p.elements.e.data.label).toBe('Old')
    expect(state.menus['owner:test'].revision).toBe(1)
  })
  it('rejects duplicate add operations and requests a future resync', () => {
    syncMenu(snapshot())
    expect(patchMenu({ menuId: 'owner:test', revision: 2, operations: [
      { op: 'element:add', pageId: 'p', element: { elementId: 'e', type: 'button', data: {} } },
    ] })).toBe(false)
    expect(state.menus['owner:test'].pages.p.elementOrder).toEqual(['e'])
  })
  it('rejects conflicts created within one patch batch atomically', () => {
    syncMenu(snapshot())
    expect(patchMenu({ menuId: 'owner:test', revision: 2, operations: [
      { op: 'element:add', pageId: 'p', element: { elementId: 'new', type: 'button', data: {} } },
      { op: 'element:add', pageId: 'p', element: { elementId: 'new', type: 'button', data: {} } },
    ] })).toBe(false)
    expect(state.menus['owner:test'].pages.p.elements.new).toBeUndefined()
    expect(state.menus['owner:test'].revision).toBe(1)
  })
  it('patches inactive pages without changing the active page', () => {
    const value = snapshot(); value.pages.push({ pageId: 'other', key: 'other', config: {}, elements: [{ elementId: 'other-e', type: 'textdisplay', data: { value: 'Before' } }] })
    syncMenu(value)
    expect(patchMenu({ menuId: 'owner:test', revision: 2, operations: [
      { op: 'element:update', pageId: 'other', elementId: 'other-e', changes: { value: 'After' } },
    ] })).toBe(true)
    expect(state.menus['owner:test'].activePageId).toBe('p')
    expect(state.menus['owner:test'].pages.other.elements['other-e'].data.value).toBe('After')
  })
  it('ignores prototype-pollution keys during merges', () => {
    syncMenu(snapshot())
    const changes = JSON.parse('{"__proto__":{"polluted":true},"label":"Safe"}')
    expect(patchMenu({ menuId: 'owner:test', revision: 2, operations: [{ op: 'element:update', pageId: 'p', elementId: 'e', changes }] })).toBe(true)
    expect({}.polluted).toBeUndefined()
    expect(state.menus['owner:test'].pages.p.elements.e.data.label).toBe('Safe')
  })
})
