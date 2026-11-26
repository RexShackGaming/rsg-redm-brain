const $ = (id) => document.getElementById(id);
const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-playertrade';
const post = (name, data) => fetch(`https://${res}/${name}`, { method: 'POST', body: JSON.stringify(data || {}) }).catch(() => {});

let state = null, labels = {}, imagePath = '', lockSeconds = 0, lockUntil = 0, changedUntil = 0, timer = null, modalItem = null;
const L = (k) => labels[k] || k;
const money = (cents) => (cents / 100).toFixed(2);
// Lua sends an empty list as {} or []
const list = (v) => (Array.isArray(v) ? v : Object.values(v || {}));

// built with textContent only: item names and metadata are never parsed as HTML
function el(tag, cls, text) {
    const node = document.createElement(tag);
    if (cls) node.className = cls;
    if (text !== undefined) node.textContent = text;
    return node;
}

function row(item, onClick, dim) {
    const r = el('div', `row${onClick ? ' click' : ''}${dim ? ' offered' : ''}`);
    const img = el('img');
    img.src = imagePath + (item.image || `${item.name}.png`);
    img.onerror = () => { img.style.visibility = 'hidden'; };
    const info = el('div', 'info');
    info.appendChild(el('div', 'name', item.label));
    const meta = [];
    if (item.quality !== undefined && item.quality !== null) meta.push(`${L('ui_quality')} ${Math.floor(item.quality)}%`);
    if (item.serie) meta.push(`${L('ui_serial')} ${item.serie}`);
    if (meta.length) info.appendChild(el('div', 'meta', meta.join(' · ')));
    r.title = [item.label, ...meta].join('\n');
    r.append(img, info, el('div', 'count', `x${item.amount}`));
    if (onClick) r.addEventListener('click', onClick);
    return r;
}

function fill(id, items, emptyKey, build) {
    const box = $(id), scroll = box.scrollTop;
    box.replaceChildren(...(items.length ? items.map(build) : [el('div', 'empty', L(emptyKey))]));
    box.scrollTop = scroll;
}

function renderInventory() {
    const query = $('search').value.trim().toLowerCase();
    const offered = new Set(list(state.mine.items).map((i) => i.slot));
    const items = list(state.inventory).filter((i) => !query || `${i.label} ${i.serie || ''}`.toLowerCase().includes(query));
    fill('inventory', items, 'ui_empty_inventory', (i) => row(i, () => openModal(i), offered.has(i.slot)));
}

function render() {
    const mine = list(state.mine.items), theirs = list(state.theirs.items);
    $('partner').textContent = `${state.name} [${state.id}]`;
    renderInventory();
    fill('mine', mine, 'ui_empty_offer', (i) => row(i, () => post('setItem', { slot: i.slot, amount: 0, name: i.name })));
    fill('theirs', theirs, 'ui_empty_offer', (i) => row(i));
    $('have').textContent = `$${money(state.cash)}`;
    $('mine-cash').textContent = money(state.mine.cents);
    $('theirs-cash').textContent = money(state.theirs.cents);
    $('mine-col').classList.toggle('is-ready', state.ready.mine);
    $('theirs-col').classList.toggle('is-ready', state.ready.theirs);
    // the quantity picker closes if its stack is gone
    if (modalItem && !list(state.inventory).some((i) => i.slot === modalItem.slot && i.name === modalItem.name)) closeModal();
    renderStatus();
}

function renderStatus() {
    if (!state) return;
    const both = state.ready.mine && state.ready.theirs;
    const left = Math.max(0, Math.ceil((lockUntil - Date.now()) / 1000));
    const warn = Date.now() < changedUntil;
    const empty = [state.mine, state.theirs].every((o) => !o.cents && !list(o.items).length);
    $('ready').textContent = L(state.ready.mine ? 'ui_unready' : 'ui_ready');
    // pause Ready after the other offer changes, so a last-second swap can't catch a click already on its way
    $('ready').disabled = !state.ready.mine && (empty || warn);
    $('confirm').textContent = both && left > 0 ? `${L('ui_confirm')} (${left})` : L('ui_confirm');
    $('confirm').disabled = !both || left > 0 || state.confirmed.mine;

    let key = 'ui_hint';
    if (state.confirmed.mine) key = 'ui_waiting_confirm';
    else if (state.confirmed.theirs) key = 'ui_partner_confirmed';
    else if (both) key = 'ui_check';
    else if (state.ready.mine) key = 'ui_waiting';
    else if (state.ready.theirs) key = 'ui_partner_ready';
    $('status').textContent = L(warn ? 'ui_changed' : key);
    $('status').classList.toggle('warn', warn);
}

function setState(next, fresh) {
    // warn when the other player's offer changes
    const offerKey = (o) => JSON.stringify([o.cents, list(o.items).map((i) => [i.slot, i.name, i.amount, i.quality, i.serie])]);
    if (!fresh && state && offerKey(state.theirs) !== offerKey(next.theirs)) {
        changedUntil = Date.now() + lockSeconds * 1000;
        const col = $('theirs-col');
        col.classList.remove('flash');
        void col.offsetWidth;
        col.classList.add('flash');
    }
    // keep the cash box in step with the offer, without overwriting what is being typed
    const cashBox = $('cash');
    if (fresh || (state && state.mine.cents !== next.mine.cents)) cashBox.value = next.mine.cents ? money(next.mine.cents) : '';
    state = next;
    lockUntil = Date.now() + (next.lockMs || 0);
    render();
}

function openModal(item) {
    const current = list(state.mine.items).find((i) => i.slot === item.slot);
    if (item.amount === 1) {
        post('setItem', { slot: item.slot, amount: current ? 0 : 1, name: item.name });
        return;
    }
    modalItem = item;
    $('modal-title').textContent = item.label;
    $('qty').value = current ? current.amount : item.amount;
    $('modal').classList.remove('hidden');
    $('qty').focus();
    $('qty').select();
}

function closeModal() {
    modalItem = null;
    $('modal').classList.add('hidden');
}

function addFromModal() {
    const amount = Math.floor(Number($('qty').value));
    if (!modalItem || !Number.isFinite(amount) || amount < 0) return;
    post('setItem', { slot: modalItem.slot, amount: Math.min(amount, modalItem.amount), name: modalItem.name });
    closeModal();
}

function setCash() {
    const value = Number($('cash').value.replace(',', '.') || 0);
    if (Number.isFinite(value) && value >= 0) post('setCash', { amount: value });
}

$('close').addEventListener('click', () => post('cancel'));
$('cancel').addEventListener('click', () => post('cancel'));
$('ready').addEventListener('click', () => state && post('ready', { rev: state.rev, state: !state.ready.mine }));
$('confirm').addEventListener('click', () => state && post('confirm', { rev: state.rev }));
$('cash-set').addEventListener('click', setCash);
$('cash').addEventListener('keydown', (e) => { if (e.key === 'Enter') setCash(); });
$('search').addEventListener('input', () => state && renderInventory());
$('modal-cancel').addEventListener('click', closeModal);
$('modal-add').addEventListener('click', addFromModal);
$('qty').addEventListener('keydown', (e) => { if (e.key === 'Enter') addFromModal(); });
window.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape' || !state) return;
    if (modalItem) closeModal(); else post('cancel');
});

window.addEventListener('message', ({ data }) => {
    if (data.action === 'open') {
        labels = data.labels; imagePath = data.imagePath; lockSeconds = data.lockSeconds; changedUntil = 0;
        document.querySelectorAll('[data-l]').forEach((n) => { n.textContent = L(n.dataset.l); });
        $('cash-row').classList.toggle('hidden', !data.allowCash);
        $('search').value = '';
        $('search').placeholder = L('ui_search');
        closeModal();
        $('root').classList.remove('hidden');
        setState(data.state, true);
        clearInterval(timer);
        timer = setInterval(renderStatus, 250);
    } else if (data.action === 'update' && state) {
        setState(data.state);
    } else if (data.action === 'close') {
        clearInterval(timer);
        state = null;
        closeModal();
        $('root').classList.add('hidden');
    }
});
