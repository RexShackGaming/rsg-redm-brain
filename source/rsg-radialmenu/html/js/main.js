'use strict';

const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-radialmenu';

function post(name, data) {
    return fetch(`https://${RESOURCE}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {}),
    }).catch(() => {});
}

const menu = new RadialMenu({
    parent: document.body,
    size: 375,
    onClose: () => post('closeRadial'),
    onClick: (item) => {
        if (item.items) return; // submenu, handled by RadialMenu
        if (item.shouldClose !== false) menu.close();
        post('selectItem', { itemData: { id: item.id, event: item.event } });
    },
});

// Hold-to-open settings sent by the client with every open
let holdToOpen = true;
let openKey = '';

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || data.action !== 'ui') return;
    if (data.radial) {
        holdToOpen = data.hold !== false;
        openKey = String(data.key || '');
        menu.setItems(Array.isArray(data.items) ? data.items : []);
        menu.open();
    } else {
        menu.close();
    }
});

// Hold-to-open: releasing the keybind closes the menu. Navigation keys (Enter, arrows, 1-9 ...) never do,
// otherwise opening a submenu with Enter would close the whole menu on key release.
const NAV_KEYS = new Set(['Enter', 'Escape', 'Backspace', 'Tab', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight']);
const KEY_ALIASES = { LEFTALT: 'Alt', LEFTSHIFT: 'Shift', LEFTCTRL: 'Control', SPACE: ' ', CAPS: 'CapsLock' };

function isOpenKey(e) {
    const name = KEY_ALIASES[openKey.toUpperCase()] || openKey;
    const known = openKey.toUpperCase() in KEY_ALIASES || /^[A-Za-z0-9]$/.test(openKey) || /^F\d{1,2}$/i.test(openKey);
    return known ? e.key.toLowerCase() === name.toLowerCase() : true; // unknown key name: any non-navigation key
}

document.addEventListener('keyup', (e) => {
    if (!holdToOpen || NAV_KEYS.has(e.key) || /^[1-9]$/.test(e.key)) return;
    if (isOpenKey(e)) menu.close();
});
