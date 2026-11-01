const $ = id => document.getElementById(id);
const app = $('app');
const listEl = $('dest-list');
const detailEl = $('detail');
let state = { hub: null, deliveries: [], selected: null, config: {} };
let L = {};
const T = (key, fallback) => L[key] || fallback;

const post = (name, data = {}) =>
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data)
    }).catch(() => {});

const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmtDist = m => m >= 1000 ? (m / 1000).toFixed(2) + ' km' : Math.round(m) + ' m';

function difficulty(d) {
    const max = state.config.maxDistance || 1;
    const r = d.distance / max;
    if (r < 0.4) return { label: T('ui_easy', 'Easy'), cls: 'good' };
    if (r < 0.75) return { label: T('ui_moderate', 'Moderate'), cls: 'warn' };
    return { label: T('ui_hard', 'Hard'), cls: 'bad' };
}

function renderList() {
    listEl.innerHTML = '';
    if (!state.deliveries.length) { listEl.innerHTML = `<div class="empty">${esc(T('ui_no_contracts', 'No contracts available'))}</div>`; return; }
    state.deliveries.forEach((d, i) => {
        const row = document.createElement('div');
        row.className = 'row' + (state.selected === i ? ' active' : '');
        row.innerHTML = `
            <div class="badge-icon">&#128666;</div>
            <div class="row-main">
                <div class="row-title">${esc(d.label)}</div>
                <div class="row-sub">${fmtDist(d.distance)}${d.item ? ' &middot; + ' + esc(d.item.label) : ''}</div>
            </div>
            ${d.cash > 0 ? `<div class="pill cash">$${d.cash}</div>` : ''}`;
        row.onclick = () => select(i);
        listEl.appendChild(row);
    });
}

function select(i) {
    state.selected = i;
    renderList();
    const d = state.deliveries[i];
    const diff = difficulty(d);
    detailEl.classList.remove('hidden');
    detailEl.style.animation = 'none'; void detailEl.offsetWidth; detailEl.style.animation = '';

    $('d-title').textContent = d.label;
    $('d-sub').textContent = state.hub;
    $('d-desc').textContent = d.description || '';
    $('d-dist').textContent = fmtDist(d.distance);
    $('d-time').textContent = state.config.timeLimit + ' ' + T('ui_minutes', 'min');
    $('d-wagon').textContent = d.wagon;
    const dEl = $('d-diff');
    dEl.textContent = diff.label; dEl.className = 'stat-val txt-' + diff.cls;

    const pct = Math.max(4, Math.min(100, (d.distance / (state.config.maxDistance || 1)) * 100));
    const bar = $('d-bar');
    bar.className = 'fill stat-' + diff.cls;
    bar.style.width = pct + '%';
    $('d-bar-txt').textContent = fmtDist(d.distance);

    const rw = $('d-rewards');
    rw.innerHTML = '';
    if (d.cash > 0) {
        rw.insertAdjacentHTML('beforeend', `
            <div class="reward">
                <div class="reward-img">$</div>
                <div class="reward-main"><div class="reward-title">${esc(T('ui_cash_payment', 'Cash Payment'))}</div>
                <div class="reward-sub">${esc(d.capped ? T('ui_capped', 'Capped at maximum payout') : T('ui_paid_on_arrival', 'Paid on arrival'))}</div></div>
                <div class="reward-amt txt-good">$${d.cash}</div>
            </div>`);
    }
    if (d.item) {
        const it = d.item;
        const img = it.image ? `<img src="${esc(it.image)}" onerror="this.parentNode.innerHTML='&#128230;'">` : '&#128230;';
        const chance = it.chance != null && it.chance < 1 ? Math.round(it.chance * 100) + T('ui_chance', '% chance') : T('ui_guaranteed', 'Guaranteed');
        rw.insertAdjacentHTML('beforeend', `
            <div class="reward">
                <div class="reward-img">${img}</div>
                <div class="reward-main"><div class="reward-title">${esc(it.label)}</div>
                <div class="reward-sub">${esc(T('ui_bonus_item', 'Bonus item'))} &middot; ${esc(chance)}</div></div>
                <div class="reward-amt">x${esc(it.amount)}</div>
            </div>`);
    }
    if (!rw.children.length) rw.innerHTML = `<div class="empty">${esc(T('ui_no_reward', 'No reward configured'))}</div>`;
}

function open(data) {
    state.hub = data.hub;
    state.deliveries = data.deliveries || [];
    state.config = data.config || {};
    state.selected = null;
    L = data.lang || {};
    document.querySelectorAll('[data-i18n]').forEach(el => { if (L[el.dataset.i18n]) el.textContent = L[el.dataset.i18n]; });
    $('hub-title').textContent = data.hub;
    detailEl.classList.add('hidden');
    renderList();
    app.classList.remove('hidden');
    if (state.deliveries.length) select(0);
}

function close() {
    app.classList.add('hidden');
    post('close');
}

$('close-btn').onclick = close;
$('cancel-btn').onclick = close;
$('start-btn').onclick = () => {
    if (state.selected === null) return;
    app.classList.add('hidden');
    post('start', { index: state.deliveries[state.selected].index });
};
document.addEventListener('keydown', e => { if (e.key === 'Escape' && !app.classList.contains('hidden')) close(); });

window.addEventListener('message', e => {
    const d = e.data;
    if (d.action === 'open') open(d);
    else if (d.action === 'close') app.classList.add('hidden');
});
