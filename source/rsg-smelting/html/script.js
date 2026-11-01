const $ = (id) => document.getElementById(id);
const app = $('app');
const list = $('list');
const modal = $('modal');
const qtyInput = $('qtyInput');
const progressWrap = $('progress');
const progressBox = progressWrap.querySelector('.progress-box');

let recipes = [];
let selected = null;
let progressHideTimer = null;

// Locale strings (overwritten by Lua on open)
let L = {
    smelter_title: 'Smelter', ui_subtitle: 'Ores into Bars', ui_close: 'Close', ui_can_make: 'Can make %s',
    ui_missing_ore: 'Missing ore', ui_smelt: 'Smelt', ui_smelt_item: 'Smelt %s', ui_quantity: 'Quantity',
    ui_max: 'Max', ui_max_n: '(max %s)', ui_cancel: 'Cancel', ui_time: 'Time: %ss', ui_remaining: '%ss remaining',
    ui_complete: 'Complete', ui_cancelled: 'Cancelled', ui_cancel_hint: 'Backspace to cancel',
};
const t = (key, ...args) => { let i = 0; return String(L[key] ?? key).replace(/%s/g, () => args[i++] ?? ''); };

function applyStaticStrings() {
    document.querySelectorAll('[data-l]').forEach((el) => { el.textContent = t(el.dataset.l); });
    $('closeBtn').title = t('ui_close');
}

const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-smelting';
const post = (name, data = {}) =>
    fetch(`https://${resource}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).catch(() => {});

const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const FALLBACK = 'data:image/svg+xml;utf8,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><text x="12" y="17" font-size="14" text-anchor="middle" fill="#9a9a9a">⛏</text></svg>');
const img = (src, cls) => `<img class="${cls}" src="${esc(src || '')}" onerror="this.onerror=null;this.src='${FALLBACK}'">`;

function render() {
    list.innerHTML = '';
    recipes.forEach((r) => {
        const row = document.createElement('div');
        const can = r.maxCraft > 0;
        row.className = 'row' + (can ? '' : ' disabled');
        const reqs = r.inputs
            .map((i) => `<span class="req ${i.have >= i.amount ? 'ok' : 'bad'}">${img(i.image, 'req-img')}${i.amount}x ${esc(i.label)} (${i.have})</span>`)
            .join('');
        row.innerHTML = `
            <div class="badge-icon">${img(r.image, 'badge-img')}</div>
            <div class="row-body">
                <div class="row-title">${esc(r.label)}</div>
                <div class="row-desc">${reqs}</div>
            </div>
            <div class="pill ${can ? 'ok' : ''}">${esc(can ? t('ui_can_make', r.maxCraft) : t('ui_missing_ore'))}</div>`;
        if (can) row.addEventListener('click', () => openModal(r));
        list.appendChild(row);
    });
}

function clampQty() {
    if (!selected) return 1;
    let v = parseInt(qtyInput.value, 10);
    if (isNaN(v) || v < 1) v = 1;
    if (v > selected.maxCraft) v = selected.maxCraft;
    qtyInput.value = v;
    $('modalTime').textContent = t('ui_time', Math.round((selected.time * v) / 1000));
    $('modalReqs').innerHTML = selected.inputs
        .map((i) => `<div class="modal-req">${img(i.image, 'modal-req-img')}<span>${i.amount * v}x ${esc(i.label)}</span></div>`)
        .join('');
    return v;
}

function openModal(r) {
    selected = r;
    $('modalTitle').textContent = t('ui_smelt_item', r.label);
    $('modalMax').textContent = t('ui_max_n', r.maxCraft);
    qtyInput.max = r.maxCraft;
    qtyInput.value = 1;
    clampQty();
    modal.classList.remove('hidden');
    qtyInput.focus();
}

function closeModal() {
    modal.classList.add('hidden');
    selected = null;
}

function hideApp() {
    closeModal();
    app.classList.add('hidden');
}

function closeAll() {
    hideApp();
    post('close');
}

function confirmSmelt() {
    if (!selected) return;
    const amount = clampQty();
    post('smelt', { index: selected.index, amount });
    hideApp();
}

const step = (d) => { qtyInput.value = (parseInt(qtyInput.value, 10) || 0) + d; clampQty(); };
$('closeBtn').addEventListener('click', closeAll);
$('cancelBtn').addEventListener('click', closeModal);
$('qtyMinus').addEventListener('click', () => step(-1));
$('qtyPlus').addEventListener('click', () => step(1));
$('qtyMax').addEventListener('click', () => { if (selected) { qtyInput.value = selected.maxCraft; clampQty(); } });
$('confirmBtn').addEventListener('click', confirmSmelt);
qtyInput.addEventListener('change', clampQty);

document.addEventListener('keydown', (e) => {
    if (app.classList.contains('hidden')) return;
    const modalOpen = !modal.classList.contains('hidden');
    if (e.key === 'Escape') modalOpen ? closeModal() : closeAll();
    else if (e.key === 'Enter' && modalOpen) confirmSmelt();
});

function setProgress(pct, remaining) {
    pct = Math.max(0, Math.min(100, pct || 0));
    $('progressFill').style.width = pct + '%';
    $('progressPct').textContent = pct + '%';
    $('progressTime').textContent = remaining > 0 ? t('ui_remaining', remaining) : t('ui_complete');
}

window.addEventListener('message', ({ data: d }) => {
    switch (d.action) {
        case 'open':
            if (d.strings) L = { ...L, ...d.strings };
            applyStaticStrings();
            recipes = d.recipes || [];
            $('title').textContent = d.title || t('smelter_title');
            render();
            closeModal();
            app.classList.remove('hidden');
            break;
        case 'close':
            hideApp();
            break;
        case 'progress:start':
            clearTimeout(progressHideTimer);
            progressBox.classList.remove('done', 'cancelled');
            $('progressLabel').textContent = d.label || '';
            setProgress(0, Math.ceil((d.duration || 0) / 1000));
            progressWrap.classList.remove('hidden');
            break;
        case 'progress:update':
            setProgress(d.percent, d.remaining);
            break;
        case 'progress:stop':
            if (d.cancelled) {
                progressBox.classList.add('cancelled');
                $('progressTime').textContent = t('ui_cancelled');
            } else {
                progressBox.classList.add('done');
                setProgress(100, 0);
            }
            progressHideTimer = setTimeout(() => progressWrap.classList.add('hidden'), 900);
            break;
    }
});
