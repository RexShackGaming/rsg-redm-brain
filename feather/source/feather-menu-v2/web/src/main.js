import { createApp, nextTick } from 'vue'
import App from './App.vue'
import './styles.css'
import { processMessage } from './messageHandler'
import { post } from './api'
import { state } from './store'

window.addEventListener('message', async (event) => {
  processMessage(event.data || {})
  if (event.data?.action === 'menu:destroy' && typeof event.data.menuId === 'string') {
    for (const suffix of ['position', 'size']) localStorage.removeItem(`feather-menu-v2:${event.data.menuId}:${suffix}`)
  }
  if (event.data?.action === 'element:focus' && event.data.menuId === state.activeMenuId && typeof event.data.elementId === 'string') {
    await nextTick()
    document.querySelector(`[data-element-id="${CSS.escape(event.data.elementId)}"] [data-menu-control]`)?.focus()
  }
})

createApp(App).mount('#app')
if (typeof globalThis.GetParentResourceName === 'function') post('ready')
else if (import.meta.env.DEV) import('./devFixture').then(({ loadDevelopmentFixture }) => loadDevelopmentFixture())
