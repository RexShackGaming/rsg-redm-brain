import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { nextTick } from 'vue'
import MenuShell from './MenuShell.vue'
import { post } from '../api'
import { controls, routeInput } from '../input'

vi.mock('../api', () => ({ post: vi.fn(() => Promise.resolve({ ok: true })) }))

const menu = () => ({
  menuId: 'owner:menu', revision: 1, activePageId: 'selectors', keys: {},
  config: { closable: true, draggable: true, persistPosition: false },
  navigation: {
    type: 'tabs', pages: [
      { pageId: 'display', label: 'Display' },
      { pageId: 'selectors', label: 'Selectors' },
    ],
  },
  pages: {
    selectors: {
      pageId: 'selectors', elementOrder: ['town'],
      elements: {
        town: {
          elementId: 'town', type: 'dropdown', data: {
            label: 'Town', value: 'valentine', options: [
              { label: 'Valentine', value: 'valentine' },
              { label: 'Locked', value: 'locked', disabled: true },
              { label: 'Blackwater', value: 'blackwater' },
            ],
          },
        },
      },
    },
  },
})

describe('MenuShell keyboard ownership', () => {
  beforeEach(() => {
    document.body.innerHTML = '<div id="overlay-root"></div>'
    vi.clearAllMocks()
  })
  afterEach(() => { document.body.innerHTML = '' })

  it('delays shared corner loading feedback and clears it with the operation', async () => {
    let complete
    post.mockImplementationOnce(() => new Promise((resolve) => { complete = resolve }))
    const value = menu()
    value.pages.selectors.elementOrder = ['save']
    value.pages.selectors.elements = { save: { elementId: 'save', type: 'button', data: { label: 'Save' } } }
    const wrapper = mount(MenuShell, { props: { menu: value }, attachTo: document.body })
    await wrapper.get('.button').trigger('click')
    expect(wrapper.find('.menu-busy').exists()).toBe(false)
    expect(wrapper.find('.button .busy-indicator').exists()).toBe(false)
    await new Promise((resolve) => setTimeout(resolve, 280))
    expect(wrapper.get('.menu-busy').attributes('aria-busy')).toBe('true')
    complete({ ok: true })
    await flushPromises()
    expect(wrapper.find('.menu-busy').exists()).toBe(false)
    wrapper.unmount()
  })

  it('confirms destructive buttons before dispatch and cancels without dispatch', async () => {
    const value = menu()
    value.pages.selectors.elementOrder = ['delete']
    value.pages.selectors.elements = { delete: { elementId: 'delete', type: 'button', data: { label: 'Delete', confirm: { title: 'Delete horse?', message: 'This cannot be undone.', confirmLabel: 'Delete', cancelLabel: 'Cancel' } } } }
    const wrapper = mount(MenuShell, { props: { menu: value }, attachTo: document.body })
    await wrapper.get('.button').trigger('click')
    const dialog = document.querySelector('[role="alertdialog"]')
    expect(dialog).not.toBeNull()
    expect(document.activeElement.textContent).toBe('Cancel')
    expect(post).not.toHaveBeenCalled()
    dialog.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))
    await nextTick()
    expect(document.querySelector('[role="alertdialog"]')).toBeNull()
    expect(post).not.toHaveBeenCalled()
    await flushPromises()
    await wrapper.get('.button').trigger('click')
    document.querySelector('[role="alertdialog"] button:last-child').click()
    await new Promise((resolve) => setTimeout(resolve, 0))
    expect(post).toHaveBeenCalledTimes(1)
    expect(post).toHaveBeenCalledWith('elementAction', expect.objectContaining({ elementId: 'delete', event: 'activate' }))
    wrapper.unmount()
  })

  it('cancels an unconfirmed action on page exit', async () => {
    const value = menu()
    value.pages.selectors.elementOrder = ['delete']
    value.pages.selectors.elements = { delete: { elementId: 'delete', type: 'button', data: { label: 'Delete', confirm: { title: 'Delete?', message: 'Cannot undo.', confirmLabel: 'Delete', cancelLabel: 'Cancel' } } } }
    const wrapper = mount(MenuShell, { props: { menu: value }, attachTo: document.body })
    await wrapper.get('.button').trigger('click')
    expect(document.querySelector('[role="alertdialog"]')).not.toBeNull()
    await wrapper.setProps({ menu: { ...value, activePageId: 'display', pages: { ...value.pages, display: { pageId: 'display', elementOrder: [], elements: {} } } } })
    await flushPromises()
    expect(document.querySelector('[role="alertdialog"]')).toBeNull()
    expect(post).not.toHaveBeenCalled()
    wrapper.unmount()
  })

  it('renders selected markers separately from a plain text accordion label', async () => {
    const value = menu()
    value.pages.selectors.elementOrder = ['horse']
    value.pages.selectors.elements = { horse: { elementId: 'horse', type: 'accordion', data: { label: 'Jerry', value: false, selected: true } } }
    const wrapper = mount(MenuShell, { props: { menu: value } })
    expect(wrapper.findAll('.selection-marker').map((node) => node.text())).toEqual(['<', '>'])
    expect(wrapper.get('.accordion-trigger').attributes('aria-current')).toBe('true')
    expect(wrapper.get('.accordion-trigger').text()).toContain('Jerry')
    wrapper.unmount()
  })

  it('centers opt-in accordion labels and sends open and close changes', async () => {
    const value = menu()
    value.pages.selectors.elementOrder = ['horse']
    value.pages.selectors.elements = {
      horse: { elementId: 'horse', key: 'horse', type: 'accordion', data: { key: 'horse', label: 'Morgan', value: false, labelAlign: 'center', notify: true } },
    }
    const wrapper = mount(MenuShell, { props: { menu: value } })
    const trigger = wrapper.get('.accordion-trigger')
    expect(trigger.classes()).toContain('label-centered')
    await trigger.trigger('click')
    expect(post).toHaveBeenLastCalledWith('elementAction', { menuId: value.menuId, pageId: 'selectors', elementId: 'horse', event: 'change', value: true })
    await trigger.trigger('click')
    expect(post).toHaveBeenLastCalledWith('elementAction', { menuId: value.menuId, pageId: 'selectors', elementId: 'horse', event: 'change', value: false })
    wrapper.unmount()
  })

  it('keeps fine-tuning controls mounted and out of navigation while collapsed', async () => {
    const value = menu()
    value.pages.selectors.elementOrder = ['section', 'detail']
    value.pages.selectors.elements = {
      section: { elementId: 'section', key: 'fine-tune', type: 'accordion', data: { key: 'fine-tune', label: 'Fine tune', value: false } },
      detail: { elementId: 'detail', key: 'depth', type: 'slider', data: { key: 'depth', section: 'fine-tune', label: 'Depth', value: 0, min: -1, max: 1, step: .05 } },
    }
    const wrapper = mount(MenuShell, { props: { menu: value }, attachTo: document.body })
    await nextTick()
    const trigger = wrapper.get('.accordion-trigger')
    expect(trigger.attributes('aria-expanded')).toBe('false')
    expect(wrapper.get('.accordion-panel').attributes('hidden')).toBeDefined()
    expect(controls(wrapper.element)).not.toContain(wrapper.get('input[type="range"]').element)
    trigger.element.focus()
    routeInput(wrapper.element, 'accept')
    await nextTick()
    expect(trigger.attributes('aria-expanded')).toBe('true')
    const slider = wrapper.get('input[type="range"]')
    slider.element.value = '.35'
    await slider.trigger('input')
    await trigger.trigger('click')
    expect(wrapper.get('input[type="range"]').element.value).toBe('0.35')
    expect(controls(wrapper.element)).not.toContain(slider.element)
    await trigger.trigger('click')
    expect(wrapper.get('input[type="range"]').element.value).toBe('0.35')
    wrapper.unmount()
  })

  it('lets an open dropdown own arrows and Escape', async () => {
    const wrapper = mount(MenuShell, { props: { menu: menu() }, attachTo: document.body })
    await nextTick()
    const dropdown = wrapper.get('[role="combobox"]')
    dropdown.element.focus()
    await dropdown.trigger('keydown', { key: 'ArrowDown' })
    await dropdown.trigger('keydown', { key: 'ArrowDown' })
    expect(document.activeElement).toBe(dropdown.element)
    expect(document.querySelector('#overlay-root .active')?.textContent).toContain('Blackwater')

    await dropdown.trigger('keydown', { key: 'Escape' })
    expect(document.querySelector('#overlay-root [role="listbox"]')).toBeNull()
    expect(post).not.toHaveBeenCalledWith('close', expect.anything())
    wrapper.unmount()
  })

  it('keeps Tab inside the menu and leaves text arrow keys alone', async () => {
    const value = menu()
    value.pages.selectors.elements.town = { elementId: 'town', type: 'input', data: { label: 'Text', value: 'draft' } }
    const wrapper = mount(MenuShell, { props: { menu: value }, attachTo: document.body })
    await nextTick()
    const input = wrapper.get('input'); input.element.focus()
    await input.trigger('keydown', { key: 'ArrowDown' })
    expect(document.activeElement).toBe(input.element)
    await input.trigger('keydown', { key: 'Tab' })
    expect(wrapper.element.contains(document.activeElement)).toBe(true)
    expect(document.activeElement).not.toBe(input.element)
    wrapper.unmount()
  })

  it('restores draft, focus and scroll across page navigation', async () => {
    const value = menu()
    value.pages.selectors.elements.town = { elementId: 'town', type: 'input', data: { label: 'Name', value: 'saved' } }
    value.pages.display = { pageId: 'display', elementOrder: ['other'], elements: { other: { elementId: 'other', type: 'button', data: { label: 'Other' } } } }
    const wrapper = mount(MenuShell, { props: { menu: value }, attachTo: document.body })
    await nextTick()
    const input = wrapper.get('input'); input.element.value = 'uncommitted'; await input.trigger('input'); input.element.focus()
    wrapper.get('.content').element.scrollTop = 120
    await wrapper.setProps({ menu: { ...value, activePageId: 'display' } }); await nextTick()
    expect(wrapper.find('input').exists()).toBe(false)
    await wrapper.setProps({ menu: { ...value, activePageId: 'selectors' } }); await nextTick()
    expect(wrapper.get('input').element.value).toBe('uncommitted')
    expect(document.activeElement).toBe(wrapper.get('input').element)
    expect(wrapper.get('.content').element.scrollTop).toBe(120)
    wrapper.unmount()
  })

  it('keeps configured top-left edges fixed as page content and height change', async () => {
    const value = menu()
    value.config.position = { x: '3%', y: '3%', anchor: 'top-left' }
    const wrapper = mount(MenuShell, { props: { menu: value }, attachTo: document.body })
    await nextTick()
    expect(wrapper.element.style.left).toBe('3%')
    expect(wrapper.element.style.top).toBe('3%')
    expect(wrapper.element.style.transform).toBe('none')
    await wrapper.setProps({ menu: {
      ...value, activePageId: 'display',
      config: { ...value.config, size: { height: '600px' } },
    } })
    await nextTick()
    expect(wrapper.element.style.left).toBe('3%')
    expect(wrapper.element.style.top).toBe('3%')
    expect(wrapper.element.style.transform).toBe('none')
    expect(wrapper.element.style.height).toBe('600px')
    wrapper.unmount()
  })

  it('selects bundled fonts per menu and retains the default system font', async () => {
    const value = menu()
    const wrapper = mount(MenuShell, { props: { menu: value } })
    expect(wrapper.element.style.getPropertyValue('--fm-font')).toBe('RDRLino, Georgia, serif')
    await wrapper.setProps({ menu: { ...value, config: { ...value.config, theme: { fontFamily: 'rdr' } } } })
    expect(wrapper.element.style.getPropertyValue('--fm-font')).toBe('RDRLino, Georgia, serif')
    await wrapper.setProps({ menu: { ...value, config: { ...value.config, theme: { fontFamily: 'HapnaSlabSerif' } } } })
    expect(wrapper.element.style.getPropertyValue('--fm-font')).toBe('HapnaSlabSerif')
    wrapper.unmount()
  })

  it('normalizes center placement and keeps top-left fixed while resizing', async () => {
    const value = menu()
    value.config = {
      ...value.config, resizable: true, persistSize: false, position: { x: '22%', y: '50%' },
      size: { width: '400px', maxWidth: '90vw', maxHeight: '85vh' },
    }
    let rect = { left: 100, top: 80, right: 500, bottom: 380, width: 400, height: 300 }
    const geometry = vi.spyOn(HTMLElement.prototype, 'getBoundingClientRect').mockImplementation(() => rect)
    const wrapper = mount(MenuShell, { props: { menu: value }, attachTo: document.body })
    await nextTick()
    await nextTick()
    expect(wrapper.element.style.left).toBe('100px')
    expect(wrapper.element.style.top).toBe('80px')
    expect(wrapper.element.style.transform).toBe('none')

    await wrapper.trigger('pointerdown', { button: 0, clientX: 495, clientY: 375 })
    rect = { left: 100, top: 80, right: 600, bottom: 480, width: 500, height: 400 }
    window.dispatchEvent(new MouseEvent('pointerup'))
    await nextTick()
    expect(wrapper.element.style.left).toBe('100px')
    expect(wrapper.element.style.top).toBe('80px')
    expect(wrapper.element.style.width).toBe('500px')
    expect(wrapper.element.style.height).toBe('400px')
    geometry.mockRestore()
    wrapper.unmount()
  })

  it('places consecutive elements with the same row key side by side', () => {
    const value = menu()
    value.pages.selectors.elementOrder = ['month', 'day', 'year']
    value.pages.selectors.elements = Object.fromEntries(['month', 'day', 'year'].map((id) => [id, {
      elementId: id, type: 'input', data: { label: id, value: '', row: 'birth-date' },
    }]))
    const wrapper = mount(MenuShell, { props: { menu: value } })
    const row = wrapper.get('.element-row')
    expect(row.findAll('.element-anchor')).toHaveLength(3)
    expect(row.attributes('style')).toContain('--row-columns: 3')
  })

  it('keeps footer camera controls outside the scrolling content', () => {
    const value = menu()
    value.pages.selectors.elementOrder = ['view', 'fov', 'rotate', 'left', 'right']
    value.pages.selectors.elements = {
      view: { elementId: 'view', type: 'dropdown', data: { key: 'view', slot: 'footer', label: 'Camera view', value: 'full', options: [{ value: 'full', label: 'Full Body' }] } },
      fov: { elementId: 'fov', type: 'slider', data: { key: 'fov', slot: 'footer', label: 'Camera FOV', value: 50, min: 10, max: 80, step: .25 } },
      rotate: { elementId: 'rotate', type: 'subheader', data: { key: 'rotate', slot: 'footer', value: 'Rotate' } },
      left: { elementId: 'left', type: 'button', data: { key: 'left', slot: 'footer', row: 'rotation', label: '← Left' } },
      right: { elementId: 'right', type: 'button', data: { key: 'right', slot: 'footer', row: 'rotation', label: 'Right →' } },
    }
    const wrapper = mount(MenuShell, { props: { menu: value } })
    expect(wrapper.find('.content [data-element-id]').exists()).toBe(false)
    expect(wrapper.find('footer [data-element-id="view"]').exists()).toBe(true)
    expect(wrapper.find('footer [data-element-id="fov"]').exists()).toBe(true)
    expect(wrapper.get('footer .element-row').findAll('button')).toHaveLength(2)
    wrapper.unmount()
  })
})
