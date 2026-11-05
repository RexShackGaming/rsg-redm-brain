import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import { nextTick } from 'vue'
import DropdownElement from './DropdownElement.vue'
import { post } from '../../api'

vi.mock('../../api', () => ({ post: vi.fn(() => Promise.resolve({ ok: true })) }))

const options = [
  { label: 'Valentine', value: 'valentine' },
  { label: 'Locked', value: 'locked', disabled: true },
  { label: 'Blackwater', value: 'blackwater' },
]
const props = (data = {}) => ({
  element: { elementId: 'town', data: { label: 'Town', value: 'valentine', options, ...data } },
  menu: { menuId: 'owner:menu', activePageId: 'page', config: { theme: {} } },
  page: { pageId: 'page' },
})

describe('DropdownElement', () => {
  beforeEach(() => {
    document.body.innerHTML = '<div id="overlay-root"></div>'
    vi.clearAllMocks()
  })
  afterEach(() => { document.body.innerHTML = '' })

  it('renders its selected label and opens into the overlay root', async () => {
    const wrapper = mount(DropdownElement, { props: props(), attachTo: document.body })
    expect(wrapper.get('[role="combobox"]').text()).toContain('Valentine')
    await wrapper.get('[role="combobox"]').trigger('click')
    expect(document.querySelectorAll('#overlay-root [role="option"]')).toHaveLength(3)
    wrapper.unmount()
  })

  it('emits the Contract 1 selection payload and closes', async () => {
    const wrapper = mount(DropdownElement, { props: props(), attachTo: document.body })
    await wrapper.get('[role="combobox"]').trigger('click')
    document.querySelectorAll('#overlay-root [role="option"]')[2].click()
    await nextTick()
    expect(post).toHaveBeenCalledWith('elementAction', {
      menuId: 'owner:menu', pageId: 'page', elementId: 'town', event: 'change', value: 'blackwater',
    })
    expect(document.querySelector('#overlay-root [role="listbox"]')).toBeNull()
    wrapper.unmount()
  })

  it('skips disabled options during keyboard navigation', async () => {
    const wrapper = mount(DropdownElement, { props: props(), attachTo: document.body })
    const trigger = wrapper.get('[role="combobox"]')
    await trigger.trigger('keydown', { key: 'ArrowDown' })
    await trigger.trigger('keydown', { key: 'ArrowDown' })
    await trigger.trigger('keydown', { key: 'Enter' })
    expect(post).toHaveBeenCalledWith('elementAction', expect.objectContaining({ value: 'blackwater' }))
    wrapper.unmount()
  })

  it('scrolls the list to keep the keyboard-active option visible', async () => {
    const manyOptions = Array.from({ length: 10 }, (_, index) => ({ label: `Town ${index + 1}`, value: index + 1 }))
    const wrapper = mount(DropdownElement, { props: props({ value: 1, options: manyOptions, maxVisibleOptions: 3 }), attachTo: document.body })
    const trigger = wrapper.get('[role="combobox"]')
    await trigger.trigger('keydown', { key: 'ArrowDown' })
    const list = document.querySelector('#overlay-root [role="listbox"]')
    Object.defineProperty(list, 'clientHeight', { configurable: true, value: 126 })
    for (const [index, option] of [...list.children].entries()) {
      Object.defineProperty(option, 'offsetTop', { configurable: true, value: index * 42 })
      Object.defineProperty(option, 'offsetHeight', { configurable: true, value: 42 })
    }
    await trigger.trigger('keydown', { key: 'End' })
    await nextTick()
    expect(list.scrollTop).toBe(294)
    await trigger.trigger('keydown', { key: 'ArrowDown' })
    await nextTick()
    expect(list.scrollTop).toBe(0)
    wrapper.unmount()
  })

  it('does not open when disabled', async () => {
    const wrapper = mount(DropdownElement, { props: props({ disabled: true }), attachTo: document.body })
    await wrapper.get('[role="combobox"]').trigger('click')
    expect(document.querySelector('#overlay-root [role="listbox"]')).toBeNull()
    wrapper.unmount()
  })
})
