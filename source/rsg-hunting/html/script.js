const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-hunting';

const state = {
    items: [],          // { name, label, image, price, owned }
    basket: {},         // name -> amount
    picks: {},          // name -> amount chosen in the card stepper
    imagePath: '',
    busy: false,
};

const $ = (id) => document.getElementById(id);
const app = $('app');
const grid = $('item-grid');
const basketList = $('basket-list');

function post(endpoint, data = {}) {
    return fetch(`https://${resource}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).then((r) => r.json()).catch(() => null);
}

const money = (n) => '$' + n.toFixed(2);
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const findItem = (name) => state.items.find((i) => i.name === name);
const available = (item) => Math.max(0, item.owned - (state.basket[item.name] || 0));
const imgSrc = (item) => state.imagePath + item.image;

function basketTotals() {
    let raw = 0, count = 0;
    for (const [name, amount] of Object.entries(state.basket)) {
        const item = findItem(name);
        if (!item) continue;
        raw += item.price * amount;
        count += amount;
    }
    const payout = Math.round(raw * 100) / 100;
    return { raw, count, payout };
}

/* ---------------- rendering ---------------- */
function renderGrid() {
    const q = $('search').value.trim().toLowerCase();
    const ownedOnly = $('owned-only').checked;

    const list = state.items
        .filter((i) => !q || i.label.toLowerCase().includes(q))
        .filter((i) => !ownedOnly || i.owned > 0)
        .sort((a, b) => (b.owned > 0) - (a.owned > 0) || a.label.localeCompare(b.label));

    if (!list.length) {
        grid.innerHTML = `<div class="empty">${ownedOnly ? 'You have nothing the trapper wants' : 'No goods match your search'}</div>`;
        return;
    }

    grid.innerHTML = list.map((item) => {
        const avail = available(item);
        const inBasket = state.basket[item.name] || 0;
        const pick = Math.min(state.picks[item.name] || 1, Math.max(avail, 1));
        const disabled = avail <= 0 ? 'disabled' : '';
        return `
        <div class="card ${item.owned <= 0 ? 'none' : ''}" data-name="${esc(item.name)}">
            <div class="card-img"><img src="${esc(imgSrc(item))}" onerror="this.style.visibility='hidden'"></div>
            <div class="card-name">${esc(item.label)}</div>
            <div class="card-meta">
                <span class="price">${money(item.price)}</span>
                <span class="owned">Have: ${item.owned}</span>
            </div>
            ${inBasket ? `<span class="badge in">${inBasket} in basket</span>` : ''}
            <div class="qty-row">
                <button class="qty-btn" data-act="dec" ${disabled}>&minus;</button>
                <input class="qty-input" type="number" min="1" max="${avail}" value="${avail ? pick : 0}" ${disabled}>
                <button class="qty-btn" data-act="inc" ${disabled}>+</button>
                <button class="qty-btn" data-act="max" title="Max" ${disabled}>&#8679;</button>
            </div>
            <button class="wood-btn small" data-act="add" ${disabled}>Add to Basket</button>
        </div>`;
    }).join('');
}

function renderBasket() {
    const entries = Object.entries(state.basket);
    if (!entries.length) {
        basketList.innerHTML = '<div class="empty">Your basket is empty</div>';
    } else {
        basketList.innerHTML = entries.map(([name, amount]) => {
            const item = findItem(name);
            if (!item) return '';
            return `
            <div class="row" data-name="${esc(name)}">
                <div class="row-icon"><img src="${esc(imgSrc(item))}" onerror="this.style.visibility='hidden'"></div>
                <div class="row-info">
                    <div class="row-title">${esc(item.label)}</div>
                    <div class="row-sub">${amount} &times; ${money(item.price)}</div>
                </div>
                <button class="qty-btn" data-act="bdec">&minus;</button>
                <button class="qty-btn" data-act="binc" ${available(item) <= 0 ? 'disabled' : ''}>+</button>
                <div class="row-total">${money(item.price * amount)}</div>
                <button class="round-btn row-remove" data-act="remove" title="Remove">&#10005;</button>
            </div>`;
        }).join('');
    }

    const { count, payout } = basketTotals();
    $('basket-count').textContent = `${count} item${count === 1 ? '' : 's'}`;
    $('basket-total').textContent = money(payout);
    $('btn-sell').disabled = count === 0 || state.busy;
    $('btn-clear').disabled = count === 0 || state.busy;
}

function render() { renderGrid(); renderBasket(); }

/* ---------------- basket ops ---------------- */
function addToBasket(name, amount) {
    const item = findItem(name);
    if (!item) return;
    const add = Math.min(Math.floor(amount), available(item));
    if (add <= 0) return;
    state.basket[name] = (state.basket[name] || 0) + add;
    state.picks[name] = 1;
    render();
}

function changeBasket(name, delta) {
    const item = findItem(name);
    if (!item) return;
    let next = (state.basket[name] || 0) + delta;
    next = Math.min(next, item.owned);
    if (next <= 0) delete state.basket[name]; else state.basket[name] = next;
    render();
}

function addAllOwned() {
    state.items.forEach((item) => { if (item.owned > 0) state.basket[item.name] = item.owned; });
    render();
}

// reconcile after fresh inventory data from the server
function setItems(items) {
    state.items = Array.isArray(items) ? items : [];
    for (const name of Object.keys(state.basket)) {
        const item = findItem(name);
        if (!item || item.owned <= 0) delete state.basket[name];
        else if (state.basket[name] > item.owned) state.basket[name] = item.owned;
    }
}

/* ---------------- selling ---------------- */
function openConfirm() {
    const { count, payout } = basketTotals();
    if (!count) return;
    $('modal-text').innerHTML = `Sell <b>${count}</b> item${count === 1 ? '' : 's'} to the trapper for <b>${money(payout)}</b>?`;
    $('modal').classList.remove('hidden');
}

async function commitSale() {
    $('modal').classList.add('hidden');
    if (state.busy) return;
    const basket = Object.entries(state.basket).map(([name, amount]) => ({ name, amount }));
    if (!basket.length) return;

    state.busy = true;
    renderBasket();
    const res = await post('sellBasket', basket);
    state.busy = false;

    if (res && res.ok) state.basket = {};
    if (res && res.items) setItems(res.items);
    render();
}

/* ---------------- open / close ---------------- */
function openUi(data) {
    state.imagePath = data.imagePath || '';
    state.basket = {};
    state.picks = {};
    setItems(data.items);
    $('vendor-title').textContent = data.title || 'Trapper';
    $('search').value = '';
    $('owned-only').checked = state.items.some((i) => i.owned > 0);
    $('modal').classList.add('hidden');
    app.classList.remove('hidden');
    render();
}

function closeUi(notify = true) {
    app.classList.add('hidden');
    $('modal').classList.add('hidden');
    state.basket = {};
    if (notify) post('close');
}

window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'open') openUi(d);
    else if (d.action === 'close') closeUi(false);
});

/* ---------------- events ---------------- */
grid.addEventListener('click', (e) => {
    const btn = e.target.closest('[data-act]');
    const card = e.target.closest('.card');
    if (!btn || !card || btn.disabled) return;
    const name = card.dataset.name;
    const item = findItem(name);
    const input = card.querySelector('.qty-input');
    const avail = available(item);
    let val = parseInt(input.value, 10) || 1;

    switch (btn.dataset.act) {
        case 'dec': val = Math.max(1, val - 1); break;
        case 'inc': val = Math.min(avail, val + 1); break;
        case 'max': val = avail; break;
        case 'add': addToBasket(name, Math.min(Math.max(1, val), avail)); return;
    }
    state.picks[name] = val;
    input.value = val;
});

grid.addEventListener('change', (e) => {
    if (!e.target.classList.contains('qty-input')) return;
    const name = e.target.closest('.card').dataset.name;
    const avail = available(findItem(name));
    const val = Math.min(avail, Math.max(1, parseInt(e.target.value, 10) || 1));
    state.picks[name] = val;
    e.target.value = val;
});

grid.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && e.target.classList.contains('qty-input')) {
        const card = e.target.closest('.card');
        card.querySelector('[data-act="add"]').click();
    }
});

basketList.addEventListener('click', (e) => {
    const btn = e.target.closest('[data-act]');
    const row = e.target.closest('.row');
    if (!btn || !row || btn.disabled) return;
    const name = row.dataset.name;
    if (btn.dataset.act === 'remove') { delete state.basket[name]; render(); }
    if (btn.dataset.act === 'bdec') changeBasket(name, -1);
    if (btn.dataset.act === 'binc') changeBasket(name, 1);
});

$('search').addEventListener('input', renderGrid);
$('owned-only').addEventListener('change', renderGrid);
$('btn-add-all').addEventListener('click', addAllOwned);
$('btn-clear').addEventListener('click', () => { state.basket = {}; render(); });
$('btn-sell').addEventListener('click', openConfirm);
$('btn-close').addEventListener('click', () => closeUi());
$('modal-cancel').addEventListener('click', () => $('modal').classList.add('hidden'));
$('modal-confirm').addEventListener('click', commitSale);

document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape' || app.classList.contains('hidden')) return;
    if (!$('modal').classList.contains('hidden')) $('modal').classList.add('hidden');
    else closeUi();
});
