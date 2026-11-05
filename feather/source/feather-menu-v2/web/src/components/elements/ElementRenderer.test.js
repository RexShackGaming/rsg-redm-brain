import { beforeEach, describe, expect, it, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import ElementRenderer from './ElementRenderer.vue'
import { post } from '../../api'

vi.mock('../../api', () => ({ post: vi.fn(() => Promise.resolve({ ok: true })) }))

const mountElement = (type, data, elementId = type) => mount(ElementRenderer, {
  props: {
    element: { elementId, type, data },
    menu: { menuId: 'owner:menu', config: {} },
    page: { pageId: 'page' },
  },
})

describe('ElementRenderer interactions', () => {
  beforeEach(() => vi.clearAllMocks())

  it('shows busy feedback and refuses duplicate activation until acknowledgement', async () => {
    let complete
    post.mockImplementationOnce(() => new Promise((resolve) => { complete = resolve }))
    const wrapper = mountElement('button', { label: 'Save', busyLabel: 'Saving…' })
    await wrapper.get('button').trigger('click')
    expect(wrapper.get('button').attributes('aria-busy')).toBe('true')
    expect(wrapper.text()).toBe('Save')
    expect(wrapper.find('.busy-indicator').exists()).toBe(false)
    expect(wrapper.get('button').classes()).not.toContain('pressed')
    await wrapper.get('button').trigger('click')
    expect(post).toHaveBeenCalledTimes(1)
    complete({ ok: true })
    await new Promise((resolve) => setTimeout(resolve, 0))
    expect(wrapper.get('button').attributes('disabled')).toBeUndefined()
    wrapper.unmount()
  })

  it('links inline errors to text fields without changing the draft', () => {
    for (const type of ['input', 'textarea', 'number']) {
      const wrapper = mountElement(type, { label: 'Name', value: type === 'number' ? 2 : 'Willow', error: 'Enter a valid value.' })
      const field = wrapper.get(type === 'textarea' ? 'textarea' : 'input')
      expect(field.attributes('aria-invalid')).toBe('true')
      expect(field.attributes('aria-describedby')).toBe(`${type}-error`)
      expect(wrapper.get('[role="alert"]').text()).toBe('Enter a valid value.')
      wrapper.unmount()
    }
  })

  it('renders whole slider values with an explicit decimal place', () => {
    const wrapper = mountElement('slider', { label: 'Camera FOV', value: 50, min: 10, max: 80, step: 0.25 })
    expect(wrapper.get('output').text()).toBe('50.0')
  })

  it('emits an activation from a button', async () => {
    const wrapper = mountElement('button', { label: 'Save', value: 'save' })
    await wrapper.get('button').trigger('click')
    expect(post).toHaveBeenCalledWith('elementAction', {
      menuId: 'owner:menu', pageId: 'page', elementId: 'button', event: 'activate', value: 'save', meta: undefined,
    })
  })

  it('marks button wrappers for shared spacing without changing non-button controls', () => {
    const button = mountElement('button', { label: 'Save' })
    const input = mountElement('input', { label: 'Name', value: '' })
    expect(button.classes()).toContain('button-element')
    expect(input.classes()).not.toContain('button-element')
    button.unmount()
    input.unmount()
  })

  it('toggles from its local controlled value', async () => {
    const wrapper = mountElement('toggle', { label: 'Enabled', value: false })
    await wrapper.get('button').trigger('click')
    expect(wrapper.get('button').attributes('aria-checked')).toBe('true')
    expect(post).toHaveBeenCalledWith('elementAction', expect.objectContaining({ event: 'change', value: true }))
  })

  it('emits page-arrow intent without changing the controlled readout', async () => {
    const wrapper = mountElement('pagearrows', { current: 2, total: 5 })
    await wrapper.findAll('button')[1].trigger('click')
    expect(wrapper.text()).toContain('2/5')
    expect(post).toHaveBeenCalledWith('elementAction', expect.objectContaining({ event: 'next', value: 1 }))
  })

  it('tracks a grid drag locally and commits only on pointer release', async () => {
    const wrapper = mountElement('gridslider', { label: 'Face', value: { x: 1, y: 1 }, maxx: 10, maxy: 10 })
    const grid = wrapper.get('.grid-slider')
    grid.element.getBoundingClientRect = () => ({ left: 0, top: 0, width: 100, height: 100 })
    await grid.trigger('pointerdown', { button: 0, pointerId: 7, clientX: 20, clientY: 30 })
    await grid.trigger('pointermove', { pointerId: 7, clientX: 50, clientY: 60 })
    expect(post).not.toHaveBeenCalled()
    await grid.trigger('pointerup', { pointerId: 7, clientX: 50, clientY: 60 })
    expect(post).toHaveBeenCalledTimes(1)
    expect(post).toHaveBeenCalledWith('elementAction', expect.objectContaining({ event: 'change', value: { x: 5, y: 6 } }))
  })

  it('supports bounded keyboard steps on the grid slider', async () => {
    const wrapper = mountElement('gridslider', { label: 'Face', value: { x: 1, y: 1 }, maxx: 2, maxy: 2, step: 0.25 })
    const grid = wrapper.get('.grid-slider')
    await grid.trigger('keydown', { key: 'ArrowRight' })
    expect(post).toHaveBeenCalledWith('elementAction', expect.objectContaining({ value: { x: 1.25, y: 1 } }))
    await grid.trigger('keydown', { key: 'ArrowUp' })
    expect(post).toHaveBeenLastCalledWith('elementAction', expect.objectContaining({ value: { x: 1.25, y: 0.75 } }))
  })

  it('disables page arrows at their controlled boundaries', () => {
    const first = mountElement('pagearrows', { current: 1, total: 5 })
    expect(first.findAll('button')[0].attributes('disabled')).toBeDefined()
    expect(first.findAll('button')[1].attributes('disabled')).toBeUndefined()
    const last = mountElement('pagearrows', { current: 5, total: 5 })
    expect(last.findAll('button')[1].attributes('disabled')).toBeDefined()
  })

  it.each([
    ['header', { value: 'Heading' }, 'h1'],
    ['subheader', { value: 'Subheading' }, 'h2'],
    ['textdisplay', { value: 'Read only' }, 'p'],
    ['line', {}, 'hr'],
    ['spacer', { size: 'large' }, '.spacer-large'],
  ])('renders the static %s element', (type, data, selector) => {
    expect(mountElement(type, data).find(selector).exists()).toBe(true)
  })

  it('commits text and numeric fields on change', async () => {
    const text = mountElement('input', { label: 'Name', value: 'Arthur' })
    await text.get('input').setValue('John')
    await text.get('input').trigger('change')
    expect(post).toHaveBeenLastCalledWith('elementAction', expect.objectContaining({ value: 'John' }))
    const number = mountElement('number', { label: 'Age', value: 36, min: 18, max: 99, step: 1 })
    await number.get('input').setValue(40)
    await number.get('input').trigger('change')
    expect(post).toHaveBeenLastCalledWith('elementAction', expect.objectContaining({ value: 40 }))
  })

  it('wraps an arrow selector through scalar option values', async () => {
    const wrapper = mountElement('arrows', { value: 'sunny', options: [
      { value: 'sunny', label: 'Sunny' }, { value: 'rain', label: 'Rain' },
    ] })
    await wrapper.findAll('button')[0].trigger('click')
    expect(post).toHaveBeenCalledWith('elementAction', expect.objectContaining({ value: 'rain' }))
  })

  it('selects radio and palette values', async () => {
    const radio = mountElement('radio', { label: 'Camp', value: 'quiet', options: [
      { value: 'quiet', label: 'Quiet' }, { value: 'social', label: 'Social' },
    ] })
    await radio.findAll('input')[1].setValue(true)
    expect(post).toHaveBeenLastCalledWith('elementAction', expect.objectContaining({ value: 'social' }))
    const palette = mountElement('colorpicker', { label: 'Color', value: '#a00', options: [
      { value: '#a00', label: 'Red' }, { value: '#00a', label: 'Blue' },
    ] })
    await palette.findAll('button')[1].trigger('click')
    expect(post).toHaveBeenLastCalledWith('elementAction', expect.objectContaining({ value: '#00a' }))
  })

  it('clamps read-only progress presentation', () => {
    const wrapper = mountElement('progress', { label: 'Load', value: 150, min: 0, max: 100 })
    expect(wrapper.get('[role="progressbar"] i').attributes('style')).toContain('100%')
  })

  it('emits the selected image-container child', async () => {
    const wrapper = mountElement('imageboxcontainer', { items: [
      { key: 'one', value: 'one', label: 'First', image: 'one.png' },
      { key: 'two', value: 'two', label: 'Second', image: 'two.png' },
    ] })
    await wrapper.findAll('button')[1].trigger('click')
    expect(post).toHaveBeenCalledWith('elementAction', expect.objectContaining({
      event: 'child', value: 'two', meta: { child: expect.objectContaining({ key: 'two' }) },
    }))
  })

  it('applies bounded image presentation fields to boxes and container children', () => {
    const box = mountElement('imagebox', {
      image: 'horse.png', width: '12rem', height: '8rem', aspectRatio: '3/2', objectFit: 'cover',
    })
    expect(box.get('img').attributes('style')).toContain('width: 12rem')
    expect(box.get('img').attributes('style')).toContain('height: 8rem')
    expect(box.get('img').attributes('style')).toContain('aspect-ratio: 3 / 2')
    expect(box.get('img').attributes('style')).toContain('object-fit: cover')

    const grid = mountElement('imageboxcontainer', { items: [
      { value: 'one', image: 'one.png', width: '96px', objectFit: 'contain' },
    ] })
    expect(grid.get('img').attributes('style')).toContain('width: 96px')
    expect(grid.get('img').attributes('style')).toContain('object-fit: contain')
  })

  it('does not activate a disabled button', async () => {
    const wrapper = mountElement('button', { label: 'Disabled', disabled: true })
    await wrapper.get('button').trigger('click')
    expect(post).not.toHaveBeenCalled()
  })

  it('reacts to an external controlled-value update', async () => {
    const wrapper = mountElement('toggle', { label: 'Enabled', value: false })
    await wrapper.setProps({ element: { elementId: 'toggle', type: 'toggle', data: { label: 'Enabled', value: true } } })
    expect(wrapper.get('button').attributes('aria-checked')).toBe('true')
  })

  it('keeps a text draft during unrelated label updates', async () => {
    const wrapper = mountElement('input', { label: 'Name', value: 'saved' })
    await wrapper.get('input').setValue('draft')
    await wrapper.setProps({ element: { elementId: 'input', type: 'input', data: { label: 'Translated', value: 'saved' } } })
    expect(wrapper.get('input').element.value).toBe('draft')
  })

  it('skips disabled arrow options and supports false values', async () => {
    const wrapper = mountElement('arrows', { value: true, options: [true, { value: 'locked', disabled: true }, false] })
    await wrapper.findAll('button')[1].trigger('click')
    expect(post).toHaveBeenLastCalledWith('elementAction', expect.objectContaining({ value: false }))
  })

  it('restores a canceled grid drag without a callback', async () => {
    const wrapper = mountElement('gridslider', { value: { x: 0.2, y: 0.3 }, maxx: 1, maxy: 1 })
    const grid = wrapper.get('button')
    grid.element.getBoundingClientRect = () => ({ left: 0, top: 0, width: 100, height: 100 })
    await grid.trigger('pointerdown', { button: 0, pointerId: 1, clientX: 80, clientY: 80 })
    await grid.trigger('pointercancel', { pointerId: 1 })
    expect(wrapper.get('i').attributes('style')).toContain('left: 20%')
    expect(post).not.toHaveBeenCalled()
  })

  it('clamps numeric commits and restores empty numeric input', async () => {
    const wrapper = mountElement('number', { value: 5, min: 0, max: 10 })
    await wrapper.get('input').setValue('40')
    expect(post).toHaveBeenLastCalledWith('elementAction', expect.objectContaining({ value: 10 }))
    post.mockClear()
    await wrapper.get('input').setValue('')
    expect(wrapper.get('input').element.value).toBe('5')
    expect(post).not.toHaveBeenCalled()
  })

  it('disables all image children with the parent and scales fractional progress', () => {
    const wrapper = mountElement('imageboxcontainer', { disabled: true, items: [{ value: 'one', image: 'one.png' }] })
    expect(wrapper.get('button').element.disabled).toBe(true)
    const progress = mountElement('progress', { value: 0.5, min: 0, max: 0.5 })
    expect(progress.get('i').attributes('style')).toContain('100%')
  })

  it('restores a rejected controlled toggle from the authoritative callback response', async () => {
    post.mockResolvedValueOnce({ ok: true, value: false })
    const wrapper = mountElement('toggle', { label: 'Controlled', value: false, persist: false })
    await wrapper.get('button').trigger('click')
    expect(wrapper.get('button').attributes('aria-checked')).toBe('false')
  })
})
