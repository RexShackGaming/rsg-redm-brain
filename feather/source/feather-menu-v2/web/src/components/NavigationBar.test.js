import { beforeEach, describe, expect, it, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import NavigationBar from './NavigationBar.vue'
import { post } from '../api'

vi.mock('../api', () => ({ post: vi.fn(() => Promise.resolve({ ok: true })) }))

const menu = (type = 'tabs', activePageId = 'one') => ({
  menuId: 'owner:menu', activePageId,
  navigation: {
    type, backLabel: 'Previous', nextLabel: 'Continue', finishLabel: 'Done',
    pages: [
      { pageId: 'one', label: 'One' },
      { pageId: 'two', label: 'Two' },
      { pageId: 'three', label: 'Three' },
    ],
  },
})

describe('NavigationBar', () => {
  beforeEach(() => vi.clearAllMocks())

  it('emits a tab selection intent', async () => {
    const wrapper = mount(NavigationBar, { props: { menu: menu() } })
    await wrapper.findAll('nav button')[1].trigger('click')
    expect(post).toHaveBeenCalledWith('navigationIntent', {
      menuId: 'owner:menu', mode: 'tabs', fromPageId: 'one', toPageId: 'two', action: 'select', index: 1,
    })
  })

  it('emits controlled Back and Next stepper intents', async () => {
    const wrapper = mount(NavigationBar, { props: { menu: menu('stepper', 'two') } })
    await wrapper.get('.stepper-back').trigger('click')
    expect(post).toHaveBeenLastCalledWith('navigationIntent', expect.objectContaining({ action: 'back', toPageId: 'one' }))
    await wrapper.get('.stepper-next').trigger('click')
    expect(post).toHaveBeenLastCalledWith('navigationIntent', expect.objectContaining({ action: 'next', toPageId: 'three' }))
  })

  it('emits Finish without a target from the last step', async () => {
    const wrapper = mount(NavigationBar, { props: { menu: menu('stepper', 'three') } })
    expect(wrapper.get('.stepper-next').text()).toBe('Done')
    await wrapper.get('.stepper-next').trigger('click')
    expect(post).toHaveBeenCalledWith('navigationIntent', expect.objectContaining({ action: 'finish', toPageId: undefined }))
  })

  it('does not emit from disabled navigation items', async () => {
    const value = menu(); value.navigation.pages[1].disabled = true
    const wrapper = mount(NavigationBar, { props: { menu: value } })
    await wrapper.findAll('nav button')[1].trigger('click')
    expect(post).not.toHaveBeenCalled()
  })

  it('disables direct step headings and a disabled next target', async () => {
    const value = menu('stepper'); value.navigation.allowDirectStep = false; value.navigation.pages[1].disabled = true
    const wrapper = mount(NavigationBar, { props: { menu: value } })
    expect(wrapper.findAll('nav button').every((button) => button.element.disabled)).toBe(true)
    expect(wrapper.get('.stepper-next').element.disabled).toBe(true)
    await wrapper.get('.stepper-next').trigger('click')
    expect(post).not.toHaveBeenCalled()
  })

  it('compacts long steppers so labels do not crowd the menu header', () => {
    const value = menu('stepper')
    value.navigation.pages = Array.from({ length: 8 }, (_, index) => ({
      pageId: `page-${index + 1}`,
      label: `Creation section ${index + 1}`,
    }))

    const wrapper = mount(NavigationBar, { props: { menu: value } })
    expect(wrapper.get('nav').classes()).toContain('navigation-many-steps')
  })
})
