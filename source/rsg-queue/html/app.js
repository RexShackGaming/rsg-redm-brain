const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-queue';
let L = {};
let state = null;

const $ = (id) => document.getElementById(id);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmtDur = (sec) => {
    sec = Math.max(0, Math.floor(Number(sec) || 0));
    return `${String(Math.floor(sec / 60)).padStart(2, '0')}:${String(sec % 60).padStart(2, '0')}`;
};

function post(name, body = {}) {
    return fetch(`https://${RES}/${name}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(body),
    }).then((r) => r.json()).catch(() => null);
}

/* ---------- custom dropdown ---------- */
function setupDd(el, options, value, onChange) {
    const valEl = el.querySelector('.dd-value');
    const menu = el.querySelector('.dd-menu');
    menu.innerHTML = '';
    const set = (v) => {
        const opt = options.find((o) => o.value === v) || options[0];
        if (!opt) return;
        el.dataset.value = opt.value;
        valEl.textContent = opt.label;
        menu.querySelectorAll('.dd-opt').forEach((o) => o.classList.toggle('selected', o.dataset.value === opt.value));
    };
    options.forEach((o) => {
        const d = document.createElement('div');
        d.className = 'dd-opt';
        d.dataset.value = o.value;
        d.textContent = o.label;
        d.addEventListener('mousedown', (e) => {
            e.preventDefault();
            e.stopPropagation();
            set(o.value);
            el.classList.remove('open');
            if (onChange) onChange(o.value);
        });
        menu.appendChild(d);
    });
    el.onmousedown = (e) => { if (!e.target.closest('.dd-menu')) el.classList.toggle('open'); };
    set(value);
}
document.addEventListener('mousedown', (e) => {
    document.querySelectorAll('.dd.open').forEach((d) => { if (!d.contains(e.target)) d.classList.remove('open'); });
});
const closeDds = () => document.querySelectorAll('.dd.open').forEach((d) => d.classList.remove('open'));

/* ---------- render ---------- */
function applyLabels() {
    document.querySelectorAll('[data-l]').forEach((el) => { if (L[el.dataset.l]) el.textContent = L[el.dataset.l]; });
    document.querySelectorAll('[data-ph]').forEach((el) => { if (L[el.dataset.ph]) el.placeholder = L[el.dataset.ph]; });
    $('refreshBtn').title = L.ui_refresh || 'Refresh';
}

function render() {
    if (!state) return;
    $('statOnline').textContent = `${state.online}/${state.max}`;
    $('statWaiting').textContent = state.queue.length;
    $('statReserved').textContent = state.reserved;
    const mb = $('maintBtn');
    mb.textContent = state.maintenance ? (L.ui_maint_on || 'Maintenance: On') : (L.ui_maint_off || 'Maintenance: Off');
    mb.classList.toggle('on', !!state.maintenance);

    const q = $('queueList');
    const renderedAt = Date.now();
    if (!state.queue.length) {
        q.innerHTML = `<div class="empty">${esc(L.ui_empty_queue)}</div>`;
    } else {
        q.innerHTML = state.queue.map((e) => {
            const waitedSec = Math.max(0, Math.floor(Number(e.waitedSec) || 0));
            return `
            <div class="row">
                <div class="badge">${e.pos}</div>
                <div class="info">
                    <div class="name">${esc(e.name)}</div>
                    <div class="desc">${esc(e.label)} · <span class="waited" data-base="${waitedSec}" data-at="${renderedAt}">${fmtDur(waitedSec)}</span>${e.grace ? ' · ' + esc(L.card_grace) : ''}</div>
                </div>
                <span class="pill">${e.priority}</span>
                <div class="actions">
                    ${e.tier ? '' : `<button class="wood-btn small" data-vip="${esc(e.license)}" data-name="${esc(e.name)}">${esc(L.ui_vip)}</button>`}
                    <button class="wood-btn small" data-act="queue_front" data-src="${e.src}">${esc(L.ui_front)}</button>
                    <button class="wood-btn small muted" data-act="queue_remove" data-src="${e.src}">${esc(L.ui_remove)}</button>
                </div>
            </div>`;
        }).join('');
    }

    const v = $('vipList');
    if (!state.vips.length) {
        v.innerHTML = `<div class="empty">${esc(L.ui_empty_vips)}</div>`;
    } else {
        v.innerHTML = state.vips.map((r) => {
            const exp = r.expires ? `${esc(L.ui_expires)} ${esc(r.expires)}` : esc(L.ui_permanent);
            return `
            <div class="row">
                <div class="badge">&#x2605;</div>
                <div class="info">
                    <div class="name">${esc(r.name || r.identifier)}</div>
                    <div class="desc">${esc(r.identifier)} · ${exp}</div>
                </div>
                <span class="pill ${r.expired ? 'bad' : 'good'}">${r.expired ? esc(L.ui_expired) : esc(r.label)}</span>
                <div class="actions">
                    <button class="wood-btn small muted" data-act="vip_remove" data-id="${esc(r.identifier)}">${esc(L.ui_remove)}</button>
                </div>
            </div>`;
        }).join('');
    }

    const tierEl = $('fTier');
    setupDd(tierEl, state.tiers.map((t) => ({ value: t.key, label: t.label })), tierEl.dataset.value);
}

async function act(action, data) {
    const res = await post('action', { action, data });
    if (res && res.data) { state = res.data; render(); }
    return res;
}

/* ---------- events ---------- */
function showTab(name) {
    closeDds();
    document.querySelectorAll('.tab').forEach((x) => x.classList.toggle('active', x.dataset.tab === name));
    $('view-queue').classList.toggle('hidden', name !== 'queue');
    $('view-vips').classList.toggle('hidden', name !== 'vips');
}

document.addEventListener('click', (e) => {
    const v = e.target.closest('[data-vip]');
    if (v) {
        $('fIdentifier').value = v.dataset.vip;
        $('fName').value = v.dataset.name || '';
        showTab('vips');
        return;
    }
    const b = e.target.closest('[data-act]');
    if (!b) return;
    const a = b.dataset.act;
    if (a === 'vip_remove') act(a, { identifier: b.dataset.id });
    else if (a === 'maintenance') act(a, {});
    else act(a, { src: Number(b.dataset.src) });
});

document.querySelectorAll('.tab').forEach((t) => t.addEventListener('click', () => showTab(t.dataset.tab)));

$('addBtn').addEventListener('click', async () => {
    const identifier = $('fIdentifier').value.trim();
    if (!identifier) return;
    const res = await act('vip_add', {
        identifier, name: $('fName').value.trim(), tier: $('fTier').dataset.value, days: Number($('fDays').value) || 0,
    });
    if (res && res.ok) { $('fIdentifier').value = ''; $('fName').value = ''; }
});

$('refreshBtn').addEventListener('click', async () => {
    const d = await post('refresh');
    if (d) { state = d; render(); }
});

let waitTick = null;

function tickWaited() {
    const now = Date.now();
    document.querySelectorAll('.waited').forEach((el) => {
        const base = Number(el.dataset.base) || 0;
        const at = Number(el.dataset.at) || now;
        el.textContent = fmtDur(base + Math.floor((now - at) / 1000));
    });
}

function close() {
    closeDds();
    clearInterval(waitTick);
    waitTick = null;
    $('app').classList.add('hidden');
    post('close');
}
$('closeBtn').addEventListener('click', close);
document.addEventListener('keyup', (e) => { if (e.key === 'Escape' && !$('app').classList.contains('hidden')) close(); });

let poll = null;
window.addEventListener('message', (e) => {
    const m = e.data;
    if (m.action === 'open') {
        L = m.labels || {};
        state = m.data;
        applyLabels();
        render();
        $('app').classList.remove('hidden');
        clearInterval(waitTick);
        waitTick = setInterval(tickWaited, 1000);
        clearInterval(poll);
        poll = setInterval(async () => {
            if ($('app').classList.contains('hidden')) {
                clearInterval(poll);
                clearInterval(waitTick);
                waitTick = null;
                return;
            }
            const d = await post('refresh');
            if (d) { state = d; render(); }
        }, 5000);
    } else if (m.action === 'close') {
        closeDds();
        clearInterval(poll);
        clearInterval(waitTick);
        waitTick = null;
        $('app').classList.add('hidden');
    }
});
