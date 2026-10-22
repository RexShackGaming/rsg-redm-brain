const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-fishmonger';
const $ = (id) => document.getElementById(id);

const state = { fish: [], counts: {}, cart: {}, imagePath: '', filletLabel: '', busy: false, lang: {} };

// locale lookup with {name} placeholders (strings come from locales/*.json via the client)
const L = (key, vars) => {
    let s = state.lang[key] ?? key;
    if (vars) for (const k in vars) s = s.split(`{${k}}`).join(vars[k]);
    return s;
};
function applyLang() {
    document.querySelectorAll('[data-i18n]').forEach(el => { if (state.lang[el.dataset.i18n]) el.textContent = state.lang[el.dataset.i18n]; });
    document.querySelectorAll('[data-i18n-ph]').forEach(el => { if (state.lang[el.dataset.i18nPh]) el.placeholder = state.lang[el.dataset.i18nPh]; });
    document.querySelectorAll('[data-i18n-title]').forEach(el => { if (state.lang[el.dataset.i18nTitle]) el.title = state.lang[el.dataset.i18nTitle]; });
}

function post(name, data = {}) {
    return fetch(`https://${RES}/${name}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data)
    }).then(r => r.json()).catch(() => null);
}

const money = (n) => '$' + (Math.round(n * 100) / 100).toFixed(2);
const fishByItem = (item) => state.fish.find(f => f.item === item);
const owned = (item) => state.counts[item] || 0;
const escapeHtml = (s) => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function setCart(item, qty) {
    qty = Math.max(0, Math.min(Math.floor(Number(qty) || 0), owned(item)));
    if (qty > 0) state.cart[item] = qty; else delete state.cart[item];
    render();
}

function imgTag(item) {
    return `<img src="${state.imagePath}${item}.png" onerror="this.style.display='none'">`;
}

function visibleFish() {
    const term = $('search').value.trim().toLowerCase();
    const ownedOnly = $('ownedOnly').checked;
    return state.fish.filter(f => (!ownedOnly || owned(f.item) > 0) && f.label.toLowerCase().includes(term));
}

function renderFish() {
    const list = visibleFish();
    const box = $('fishList');
    if (!list.length) { box.innerHTML = `<div class="empty">${escapeHtml(L('ui_no_fish'))}</div>`; return; }

    box.innerHTML = list.map(f => {
        const have = owned(f.item), inCart = state.cart[f.item] || 0, left = have - inCart;
        return `<div class="row ${have === 0 ? 'disabled' : ''}" data-item="${f.item}">
            <div class="badge-icon">${imgTag(f.item)}</div>
            <div class="row-info">
                <div class="row-title">${escapeHtml(f.label)}</div>
                <div class="row-desc">${money(f.price)} ${escapeHtml(L('ui_each'))} &middot; ${f.fillets} ${escapeHtml(L('ui_fillets'))}</div>
                <div style="margin-top:6px"><span class="pill ${have > 0 ? 'ok' : ''}">${escapeHtml(L('ui_owned'))} ${have}</span>${inCart ? ` <span class="pill">${escapeHtml(L('ui_in_cart'))} ${inCart}</span>` : ''}</div>
            </div>
            <div class="row-actions">
                <div class="qty">
                    <button data-act="dec">-</button>
                    <input type="number" min="1" max="${left}" value="${left > 0 ? 1 : 0}" data-act="qty">
                    <button data-act="inc">+</button>
                </div>
                <div class="btns">
                    <button class="wood-btn sm" data-act="add" ${left <= 0 ? 'disabled' : ''}>${escapeHtml(L('ui_add'))}</button>
                    <button class="wood-btn sm muted" data-act="addall" ${left <= 0 ? 'disabled' : ''}>${escapeHtml(L('ui_all'))}</button>
                </div>
            </div>
        </div>`;
    }).join('');
}

function renderCart() {
    const items = Object.keys(state.cart);
    const box = $('cartList');
    let tFish = 0, tCash = 0, tFil = 0;
    if (!items.length) {
        box.innerHTML = `<div class="empty">${escapeHtml(L('ui_cart_empty'))}</div>`;
    } else {
        box.innerHTML = items.map(item => {
            const f = fishByItem(item), q = state.cart[item];
            tFish += q; tCash += f.price * q; tFil += f.fillets * q;
            return `<div class="row" data-item="${item}">
                <div class="badge-icon">${imgTag(item)}</div>
                <div class="row-info">
                    <div class="row-title">${escapeHtml(f.label)}</div>
                    <div class="row-desc">${money(f.price * q)} &middot; ${f.fillets * q} ${escapeHtml(L('ui_fillets'))}</div>
                </div>
                <div class="qty">
                    <button data-act="cdec">-</button>
                    <input type="number" min="0" max="${owned(item)}" value="${q}" data-act="cqty">
                    <button data-act="cinc">+</button>
                </div>
                <button class="circle-btn" data-act="remove" title="${escapeHtml(L('ui_remove'))}">&#10005;</button>
            </div>`;
        }).join('');
    }
    $('totFish').textContent = tFish;
    $('totCash').textContent = money(tCash);
    $('totFillets').textContent = tFil;
    const empty = !items.length || state.busy;
    $('sellBtn').disabled = empty; $('processBtn').disabled = empty; $('clearBtn').disabled = !items.length;
    $('addAllBtn').disabled = !visibleFish().some(f => owned(f.item) > (state.cart[f.item] || 0));
    return { tFish, tCash, tFil };
}

function render() { renderFish(); renderCart(); }

// fish list interactions
$('fishList').addEventListener('click', (e) => {
    const act = e.target.dataset.act; if (!act || act === 'qty') return;
    const row = e.target.closest('.row'); if (!row || row.classList.contains('disabled')) return;
    const item = row.dataset.item;
    const input = row.querySelector('input');
    const left = owned(item) - (state.cart[item] || 0);
    if (act === 'inc') input.value = Math.min(left, (+input.value || 0) + 1);
    if (act === 'dec') input.value = Math.max(Math.min(1, left), (+input.value || 0) - 1);
    if (act === 'add') setCart(item, (state.cart[item] || 0) + Math.min(left, Math.max(1, +input.value || 1)));
    if (act === 'addall') setCart(item, owned(item));
});

// cart interactions
$('cartList').addEventListener('click', (e) => {
    const act = e.target.dataset.act; if (!act || act === 'cqty') return;
    const item = e.target.closest('.row').dataset.item;
    if (act === 'cinc') setCart(item, state.cart[item] + 1);
    if (act === 'cdec') setCart(item, state.cart[item] - 1);
    if (act === 'remove') setCart(item, 0);
});
$('fishList').addEventListener('change', (e) => {
    if (e.target.dataset.act !== 'qty') return;
    const item = e.target.closest('.row').dataset.item;
    const left = owned(item) - (state.cart[item] || 0);
    e.target.value = Math.max(Math.min(1, left), Math.min(left, Math.floor(+e.target.value || 0)));
});
$('cartList').addEventListener('change', (e) => {
    if (e.target.dataset.act !== 'cqty') return;
    setCart(e.target.closest('.row').dataset.item, e.target.value);
});

$('search').addEventListener('input', render);
$('ownedOnly').addEventListener('change', render);
$('addAllBtn').addEventListener('click', () => { visibleFish().forEach(f => { if (owned(f.item) > 0) state.cart[f.item] = owned(f.item); }); render(); });
$('clearBtn').addEventListener('click', () => { state.cart = {}; render(); });
$('closeBtn').addEventListener('click', () => post('close'));

let pendingMode = null;

function confirmCheckout(mode) {
    if (state.busy || !Object.keys(state.cart).length) return;
    const t = renderCart();
    pendingMode = mode;
    $('modalTitle').textContent = L(mode === 'sell' ? 'ui_sell_title' : 'ui_process_title');
    $('modalText').textContent = mode === 'sell'
        ? L('ui_sell_confirm', { fish: t.tFish, cash: money(t.tCash) })
        : L('ui_process_confirm', { fish: t.tFish, fillets: t.tFil, label: state.filletLabel });
    $('modal').classList.remove('hidden');
}
function closeModal() { pendingMode = null; $('modal').classList.add('hidden'); }

$('sellBtn').addEventListener('click', () => confirmCheckout('sell'));
$('processBtn').addEventListener('click', () => confirmCheckout('process'));
$('modalCancel').addEventListener('click', closeModal);
$('modalConfirm').addEventListener('click', () => {
    if (!pendingMode || state.busy) return;
    const mode = pendingMode;
    closeModal();
    state.busy = true;
    post('checkout', { mode, cart: state.cart });
    state.cart = {};
    $('app').classList.add('hidden');
});

document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape' || $('app').classList.contains('hidden')) return;
    if (!$('modal').classList.contains('hidden')) { closeModal(); return; }
    post('close');
});

window.addEventListener('message', (e) => {
    const d = e.data;
    if (d.action === 'open') {
        Object.assign(state, {
            fish: d.fish || [], counts: d.counts || {}, cart: {}, busy: false,
            imagePath: d.imagePath || '', filletLabel: d.filletLabel || '', lang: d.lang || {}
        });
        applyLang();
        $('title').textContent = d.title || '';
        $('subtitle').textContent = d.subtitle || '';
        $('filletName').textContent = state.filletLabel;
        $('search').value = '';
        $('ownedOnly').checked = true;
        $('modal').classList.add('hidden');
        $('app').classList.remove('hidden');
        render();
    } else if (d.action === 'close') {
        $('app').classList.add('hidden');
        $('modal').classList.add('hidden');
    }
});
