import { handleMessage, state } from './store'

export function simulateDevelopmentAction(endpoint, payload) {
  const menu = state.menus[payload.menuId]
  if (!menu) return { ok: true }
  if (endpoint === 'close' || (endpoint === 'navigationIntent' && payload.action === 'finish')) {
    handleMessage({ action: 'menu:close', menuId: menu.menuId })
  }
  if (endpoint === 'navigationIntent' && payload.toPageId) {
    handleMessage({ action: 'menu:patch', menuId: menu.menuId, revision: menu.revision + 1,
      operations: [{ op: 'page:activate', pageId: payload.toPageId }] })
  }
  if (endpoint === 'elementAction' && payload.event === 'change') {
    handleMessage({ action: 'menu:patch', menuId: menu.menuId, revision: menu.revision + 1,
      operations: [{ op: 'element:update', pageId: payload.pageId, elementId: payload.elementId, changes: { value: payload.value } }] })
    return { ok: true, value: payload.value }
  }
  return { ok: true }
}

export function loadDevelopmentFixture() {
  if (new URLSearchParams(window.location.search).get('view') === 'stepper') {
    loadStepperFixture()
    return
  }
  const menuId = 'fixture:showcase'
  const main = 'fixture:showcase/main'
  const advanced = 'fixture:showcase/advanced'
  const element = (key, type, data) => ({ elementId: `${main}/${key}`, key, type, data })
  handleMessage({ action: 'menu:sync', menu: {
    menuId, key: 'showcase', revision: 1, activePageId: main, open: true,
    config: {
      draggable: true, resizable: true, closable: true, persistPosition: false,
      position: { x: '50%', y: '50%' },
      size: { width: '34rem', minWidth: '24rem', maxHeight: '82vh' },
      theme: { preset: 'redemption', accent: '#a73732' },
    },
    navigation: { type: 'tabs', pages: [{ pageId: main, label: 'General' }, { pageId: advanced, label: 'Appearance' }] },
    pages: [
      { pageId: main, key: 'main', config: {}, elements: [
        element('header', 'header', { value: 'Feather Menu v2', slot: 'header' }),
        element('description', 'textdisplay', { value: 'Reactive controls, bounded themes, dragging, resizing, and overlay choices.' }),
        element('name', 'input', { label: 'Character name', placeholder: 'Enter a name', value: 'Arthur' }),
        element('number', 'number', { label: 'Age', value: 35, min: 18, max: 99, step: 1 }),
        element('dropdown', 'dropdown', { label: 'Home town', value: 'valentine', maxVisibleOptions: 6, options: [
          { value: 'valentine', label: 'Valentine' }, { value: 'saint-denis', label: 'Saint Denis' },
          { value: 'blackwater', label: 'Blackwater' }, { value: 'rhodes', label: 'Rhodes' },
          { value: 'strawberry', label: 'Strawberry' }, { value: 'annesburg', label: 'Annesburg' },
          { value: 'van-horn', label: 'Van Horn' }, { value: 'armadillo', label: 'Armadillo' },
          { value: 'tumbleweed', label: 'Tumbleweed' }, { value: 'lagras', label: 'Lagras' },
        ] }),
        element('radio', 'radio', { label: 'Camp preference', value: 'quiet', options: [{ value: 'quiet', label: 'Quiet' }, { value: 'social', label: 'Social' }] }),
        element('slider', 'slider', { label: 'Volume', value: 65, min: 0, max: 100, step: 5 }),
        element('progress', 'progress', { label: 'Character setup', value: 72, min: 0, max: 100 }),
        element('grid', 'gridslider', { label: 'Two-axis grid slider', value: { x: 0.25, y: 0.65 }, maxx: 1, maxy: 1 }),
        element('colors', 'colorpicker', { label: 'Accent color', value: '#a73732', options: ['#a73732', '#315b85', '#54734d', '#9b7439', '#72528f'] }),
        element('continue', 'button', { label: 'Continue', slot: 'footer' }),
      ] },
      { pageId: advanced, key: 'advanced', config: {}, elements: [] },
    ],
  } })
  handleMessage({ action: 'menu:open', menuId, pageId: main })
}

function loadStepperFixture() {
  const menuId = 'fixture:stepper'
  const definitions = [
    ['general', 'General'], ['face', 'Face'], ['upper', 'Upper Body'], ['lower', 'Lower Body'], ['review', 'Review'],
  ]
  const pageId = (key) => `${menuId}/${key}`
  handleMessage({ action: 'menu:sync', menu: {
    menuId, key: 'stepper', revision: 1, activePageId: pageId('general'), open: true,
    config: {
      draggable: true, closable: true, persistPosition: false,
      position: { x: '50%', y: '50%' }, size: { width: '36rem', maxHeight: '84vh' },
      theme: { preset: 'redemption', accent: '#54734d' },
    },
    navigation: {
      type: 'stepper', backLabel: 'Back', nextLabel: 'Next', finishLabel: 'Finish',
      pages: definitions.map(([key, label]) => ({ pageId: pageId(key), label })),
    },
    pages: definitions.map(([key, label]) => ({
      pageId: pageId(key), key, config: {}, elements: [
        { elementId: `${pageId(key)}/title`, key: 'title', type: 'header', data: { value: label, slot: 'header' } },
        { elementId: `${pageId(key)}/help`, key: 'help', type: 'textdisplay', data: { value: 'Complete this section, then continue with Next. You can return to an earlier completed step at any time.' } },
      ],
    })),
  } })
  handleMessage({ action: 'menu:open', menuId, pageId: pageId('general') })
}
