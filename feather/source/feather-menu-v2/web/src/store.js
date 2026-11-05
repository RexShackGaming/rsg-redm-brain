import { reactive } from 'vue'

export const state = reactive({ menus: {}, activeMenuId: null })
const blockedKeys = new Set(['__proto__', 'prototype', 'constructor'])

const record = (value) => value !== null && typeof value === 'object' && !Array.isArray(value)

function pageMap(pages = []) {
  return Object.fromEntries(pages.map((page) => [page.pageId, {
    ...page,
    elements: Object.fromEntries((page.elements || []).map((element) => [element.elementId, element])),
    elementOrder: (page.elements || []).map((element) => element.elementId),
  }]))
}

export function syncMenu(snapshot) {
  if (!record(snapshot) || typeof snapshot.menuId !== 'string' || !Number.isInteger(snapshot.revision)
    || !record(snapshot.config) || !Array.isArray(snapshot.pages)) return false
  if (snapshot.activePageId !== null && snapshot.activePageId !== undefined && typeof snapshot.activePageId !== 'string') return false
  if (snapshot.navigation !== null && snapshot.navigation !== undefined && !record(snapshot.navigation)) return false
  const emptyKeysArray = Array.isArray(snapshot.keys) && snapshot.keys.length === 0
  if (snapshot.keys !== undefined && !record(snapshot.keys) && !emptyKeysArray) return false
  if (snapshot.pages.some((page) => !record(page) || typeof page.pageId !== 'string' || !record(page.config) || !Array.isArray(page.elements)
    || page.elements.some((element) => !record(element) || typeof element.elementId !== 'string'
      || typeof element.type !== 'string' || !record(element.data)))) return false
  const pageIds = snapshot.pages.map((page) => page.pageId)
  if (new Set(pageIds).size !== pageIds.length) return false
  if (snapshot.pages.some((page) => new Set(page.elements.map((element) => element.elementId)).size !== page.elements.length)) return false
  if (snapshot.activePageId && !pageIds.includes(snapshot.activePageId)) return false
  const current = state.menus[snapshot.menuId]
  if (current && snapshot.revision < current.revision) return false
  state.menus[snapshot.menuId] = {
    ...snapshot,
    pages: pageMap(snapshot.pages),
    pageOrder: snapshot.pages.map((page) => page.pageId),
    position: current?.position,
    keys: record(snapshot.keys) ? snapshot.keys : {},
  }
  if (snapshot.open) state.activeMenuId = snapshot.menuId
  else if (state.activeMenuId === snapshot.menuId) state.activeMenuId = null
  return true
}

function merge(target, changes) {
  for (const [key, value] of Object.entries(changes || {})) {
    if (blockedKeys.has(key)) continue
    if (value && typeof value === 'object' && !Array.isArray(value) && target[key] && typeof target[key] === 'object' && !Array.isArray(target[key])) {
      merge(target[key], value)
    } else target[key] = value
  }
}

function validOperation(menu, operation) {
  if (!record(operation) || typeof operation.op !== 'string') return false
  if (operation.op === 'menu:update') return record(operation.changes)
  if (operation.op === 'page:add') return record(operation.page) && typeof operation.page.pageId === 'string' && !menu.pages[operation.page.pageId]
  if (operation.op === 'page:activate') return typeof operation.pageId === 'string' && !!menu.pages[operation.pageId]
  if (operation.op === 'page:update') return !!menu.pages[operation.pageId] && record(operation.changes)
  if (operation.op === 'page:remove') return !!menu.pages[operation.pageId]
  if (operation.op === 'element:add') return !!menu.pages[operation.pageId] && record(operation.element)
    && typeof operation.element.elementId === 'string' && record(operation.element.data)
    && !menu.pages[operation.pageId].elements[operation.element.elementId]
  if (operation.op === 'element:update') return !!menu.pages[operation.pageId]?.elements[operation.elementId] && record(operation.changes)
  if (operation.op === 'element:remove') return !!menu.pages[operation.pageId]?.elements[operation.elementId]
  if (operation.op === 'navigation:set') return operation.navigation === null || operation.navigation === false || record(operation.navigation)
  if (operation.op === 'navigation:update') return record(menu.navigation) && record(operation.changes)
  if (operation.op === 'key:set' || operation.op === 'key:remove') return typeof operation.key === 'string'
  return false
}

function validateBatch(menu, operations) {
  const pages = new Map(Object.entries(menu.pages).map(([pageId, page]) => [pageId, new Set(page.elementOrder)]))
  for (const operation of operations) {
    const shadow = {
      ...menu,
      pages: Object.fromEntries([...pages].map(([pageId, elementIds]) => [pageId, {
        elements: Object.fromEntries([...elementIds].map((elementId) => [elementId, true])),
      }])),
    }
    if (!validOperation(shadow, operation)) return false
    if (operation.op === 'page:add') pages.set(operation.page.pageId, new Set())
    if (operation.op === 'page:remove') pages.delete(operation.pageId)
    if (operation.op === 'element:add') pages.get(operation.pageId).add(operation.element.elementId)
    if (operation.op === 'element:remove') pages.get(operation.pageId).delete(operation.elementId)
  }
  return true
}

export function patchMenu(message) {
  if (!record(message) || typeof message.menuId !== 'string' || !Number.isInteger(message.revision) || !Array.isArray(message.operations)) return false
  const menu = state.menus[message.menuId]
  if (!menu || message.revision !== menu.revision + 1) return false
  if (!validateBatch(menu, message.operations)) return false
  for (const operation of message.operations) {
    if (operation.op === 'menu:update') merge(menu.config, operation.changes)
    if (operation.op === 'page:add') {
      menu.pages[operation.page.pageId] = { ...operation.page, elements: {}, elementOrder: [] }
      menu.pageOrder.push(operation.page.pageId)
    }
    if (operation.op === 'page:activate') menu.activePageId = operation.pageId
    if (operation.op === 'page:update') { const page = menu.pages[operation.pageId]; if (page) merge(page.config, operation.changes) }
    if (operation.op === 'page:remove') {
      delete menu.pages[operation.pageId]
      menu.pageOrder = menu.pageOrder.filter((id) => id !== operation.pageId)
      if (menu.activePageId === operation.pageId) menu.activePageId = operation.fallbackPageId
    }
    if (operation.op === 'element:add') {
      const page = menu.pages[operation.pageId]
      if (page) { page.elements[operation.element.elementId] = operation.element; page.elementOrder.push(operation.element.elementId) }
    }
    if (operation.op === 'element:update') {
      const element = menu.pages[operation.pageId]?.elements[operation.elementId]
      if (element) merge(element.data, operation.changes)
    }
    if (operation.op === 'element:remove') {
      const page = menu.pages[operation.pageId]
      if (page) { delete page.elements[operation.elementId]; page.elementOrder = page.elementOrder.filter((id) => id !== operation.elementId) }
    }
    if (operation.op === 'navigation:set') menu.navigation = operation.navigation
    if (operation.op === 'navigation:update' && menu.navigation) merge(menu.navigation, operation.changes)
    if (operation.op === 'key:set') menu.keys[operation.key] = true
    if (operation.op === 'key:remove') delete menu.keys[operation.key]
  }
  menu.revision = message.revision
  return true
}

export function handleMessage(data) {
  if (!record(data) || typeof data.action !== 'string') return false
  if (data.action === 'menu:sync') return syncMenu(data.menu)
  if (data.action === 'menu:patch') return patchMenu(data)
  if (!['menu:open', 'menu:close', 'menu:destroy'].includes(data.action) || typeof data.menuId !== 'string') return false
  if (data.action !== 'menu:destroy' && !state.menus[data.menuId]) return false
  if (data.action === 'menu:open') { state.activeMenuId = data.menuId; state.menus[data.menuId].open = true }
  if (data.action === 'menu:close') { state.menus[data.menuId].open = false; if (state.activeMenuId === data.menuId) state.activeMenuId = null }
  if (data.action === 'menu:destroy') { delete state.menus[data.menuId]; if (state.activeMenuId === data.menuId) state.activeMenuId = null }
  return true
}
