const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'rsg-noticeboard';
const $ = (id) => document.getElementById(id);
const post = (name, data = {}) => fetch(`https://${RES}/${name}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data)
}).then(r => r.json()).catch(() => ({}));

const state = { data: null, admin: null, category: 'all', duration: null, clockOffset: 0 };
let durationCb = null, inputCb = null, confirmCb = null;
const cancelHandlers = {};

let LOCALE = {};
// L('ui_key', a, b) -> locale string with %s / %d replaced in order
const L = (key, ...args) => {
    let i = 0;
    return String(LOCALE[key] ?? key).replace(/%[sd]/g, () => String(args[i++] ?? ''));
};
function applyLocale() {
    document.querySelectorAll('[data-i18n]').forEach(el => el.textContent = L(el.dataset.i18n));
    document.querySelectorAll('[data-i18n-placeholder]').forEach(el => el.placeholder = L(el.dataset.i18nPlaceholder));
    document.querySelectorAll('[data-i18n-title]').forEach(el => el.title = L(el.dataset.i18nTitle));
}

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const safeUrl = (u) => (typeof u === 'string' && /^https:\/\/[^\s"'<>()]+$/i.test(u)) ? u : '';
const money = (n) => '$' + Number(n || 0).toFixed(2);
const nowServer = () => Math.floor(Date.now() / 1000) + state.clockOffset;
const townLabel = (cfg, id) => id ? ((cfg.towns || []).find(t => t.id === id) || {}).label || id : L('ui_all_towns');
const catLabel = (cfg, id) => (cfg.categories.find(c => c.id === id) || {}).label || id;

function timeLeft(exp) {
    let s = Math.max(0, exp - nowServer());
    const d = Math.floor(s / 86400); s %= 86400;
    const h = Math.floor(s / 3600); const m = Math.floor((s % 3600) / 60);
    if (d > 0) return L('ui_time_d', d, h);
    if (h > 0) return L('ui_time_h', h, m);
    return L('ui_time_m', m);
}

function toast(msg, type = 'info', label) {
    const el = document.createElement('div');
    el.className = `toast ${type}`;
    el.innerHTML = `<div class="t-label">${esc(label || L(type === 'error' ? 'ui_toast_error' : type === 'success' ? 'ui_toast_success' : 'ui_toast_info'))}</div><div class="t-msg">${esc(msg)}</div>`;
    $('toasts').appendChild(el);
    setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 260); }, 3500);
}

/* ---------- open / close ---------- */
window.addEventListener('message', (e) => {
    const { action, data, locale } = e.data || {};
    if (locale) { LOCALE = locale; applyLocale(); }
    if (action === 'openBoard') { setBoardData(data); show('board'); }
    if (action === 'openAdmin') { setAdminData(data); show('admin'); }
});

function show(which) {
    $('app').classList.remove('hidden');
    $('board').classList.toggle('hidden', which !== 'board');
    $('admin').classList.toggle('hidden', which !== 'admin');
    closeModals();
}

function closeAll() {
    $('app').classList.add('hidden');
    closeModals();
    post('close');
}

function openModal(id) {
    document.querySelectorAll('.modal').forEach(m => m.classList.add('hidden'));
    $('modalBackdrop').classList.remove('hidden');
    $(id).classList.remove('hidden');
}
function closeModals() {
    $('modalBackdrop').classList.add('hidden');
    document.querySelectorAll('.modal').forEach(m => m.classList.add('hidden'));
}

document.querySelectorAll('.close-btn').forEach(b => b.addEventListener('click', closeAll));
document.querySelectorAll('[data-close-modal]').forEach(b => b.addEventListener('click', closeModals));
document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape' || $('app').classList.contains('hidden')) return;
    if ($('modalBackdrop').classList.contains('hidden')) return closeAll();
    // escape behaves like the open modal's cancel button (so nested dialogs return to their parent)
    const open = document.querySelector('.modal:not(.hidden) [data-close-modal]');
    if (open) open.click(); else closeModals();
});

/* ---------- player board ---------- */
function setBoardData(data) {
    state.data = data;
    state.clockOffset = data.now - Math.floor(Date.now() / 1000);
    $('boardTown').textContent = data.town ? L('ui_board_sub_town', data.town) : L('ui_board_sub');
    renderTabs(); renderGrid();
}

async function refreshBoard() {
    const data = await post('refresh');
    if (data && data.notices) setBoardData(data);
}

function renderTabs() {
    const cfg = state.data.config;
    const tabs = [{ id: 'all', label: L('ui_all') }, ...cfg.categories];
    $('categoryTabs').innerHTML = tabs.map(c => {
        const n = c.id === 'all' ? state.data.notices.length : state.data.notices.filter(x => x.category === c.id).length;
        return `<button class="tab ${state.category === c.id ? 'active' : ''}" data-cat="${esc(c.id)}">${esc(c.label)} (${n})</button>`;
    }).join('');
    $('categoryTabs').querySelectorAll('.tab').forEach(t => t.addEventListener('click', () => {
        state.category = t.dataset.cat; renderTabs(); renderGrid();
    }));
}

function renderGrid() {
    const cfg = state.data.config;
    const list = state.data.notices.filter(n => state.category === 'all' || n.category === state.category);
    $('noticeEmpty').classList.toggle('hidden', list.length > 0);
    $('noticeGrid').innerHTML = list.map(n => {
        const img = safeUrl(n.image);
        return `<div class="tile" data-id="${n.id}">
            <div class="tile-img ${img ? '' : 'noimg'}" ${img ? `style="background-image:url('${esc(img)}')"` : ''}>${img ? '' : '&#10022;'}</div>
            <span class="pill">${esc(catLabel(cfg, n.category))}</span>
            ${n.mine ? `<span class="pill mine">${esc(L('ui_yours'))}</span>` : ''}
            <div class="tile-title">${esc(n.title)}</div>
            <div class="tile-meta"><span>${esc(n.author)}</span><span>${timeLeft(n.expires_at)}</span></div>
        </div>`;
    }).join('');
    $('noticeGrid').querySelectorAll('.tile').forEach(t => t.addEventListener('click', () => viewNotice(Number(t.dataset.id))));
    // swap broken poster images for the placeholder
    $('noticeGrid').querySelectorAll('.tile-img:not(.noimg)').forEach(el => {
        const url = el.style.backgroundImage.slice(5, -2), img = new Image();
        img.onerror = () => { el.style.backgroundImage = ''; el.classList.add('noimg'); el.innerHTML = '&#10022;'; };
        img.src = url;
    });
}

function viewNotice(id) {
    const n = state.data.notices.find(x => x.id === id);
    if (!n) return;
    $('viewCat').textContent = catLabel(state.data.config, n.category);
    $('viewTitle').textContent = n.title;
    $('viewBody').textContent = n.body;
    $('viewAuthor').textContent = L('ui_posted_by', n.author);
    $('viewExpires').textContent = L('ui_expires_in', timeLeft(n.expires_at));
    const img = safeUrl(n.image);
    $('viewImage').classList.toggle('hidden', !img);
    if (img) $('viewImage').src = img; else $('viewImage').removeAttribute('src');
    openModal('viewModal');
}
$('viewImage').addEventListener('error', () => $('viewImage').classList.add('hidden'));

/* create */
function renderDurationPicker(container, durations, selected, onPick) {
    container.innerHTML = durations.map(d =>
        `<div class="dur ${selected === d.id ? 'active' : ''}" data-id="${esc(d.id)}"><div class="d-label">${esc(d.label)}</div><div class="d-price">${money(d.price)}</div></div>`).join('');
    container.querySelectorAll('.dur').forEach(el => el.addEventListener('click', () => {
        container.querySelectorAll('.dur').forEach(x => x.classList.remove('active'));
        el.classList.add('active'); onPick(el.dataset.id);
    }));
}

function updateFee() {
    const cfg = state.data.config;
    const d = cfg.durations.find(x => x.id === state.duration);
    const fee = d ? d.price : 0;
    $('feeValue').textContent = money(fee);
    $('cashValue').textContent = money(state.data.cash);
    $('feeValue').classList.toggle('over', fee > state.data.cash);
    $('btnSubmit').disabled = fee > state.data.cash; // can't afford it, don't let them try
}

$('btnNew').addEventListener('click', () => {
    const cfg = state.data.config;
    $('inTitle').value = ''; $('inBody').value = ''; $('inImage').value = '';
    $('inTitle').maxLength = cfg.titleMax; $('inBody').maxLength = cfg.bodyMax;
    $('imgPreviewWrap').classList.add('hidden');
    $('inCategory').innerHTML = cfg.categories.map(c => `<option value="${esc(c.id)}">${esc(c.label)}</option>`).join('');
    if (state.category !== 'all') $('inCategory').value = state.category;
    state.duration = cfg.durations[0] && cfg.durations[0].id;
    renderDurationPicker($('durationPick'), cfg.durations, state.duration, (id) => { state.duration = id; updateFee(); });
    updateCounts(); updateFee();
    openModal('createModal');
    $('inTitle').focus();
});

function updateCounts() {
    const cfg = state.data.config;
    $('titleCount').textContent = `${$('inTitle').value.length}/${cfg.titleMax}`;
    $('bodyCount').textContent = `${$('inBody').value.length}/${cfg.bodyMax}`;
}
$('inTitle').addEventListener('input', updateCounts);
$('inBody').addEventListener('input', updateCounts);
$('inImage').addEventListener('input', () => {
    const u = safeUrl($('inImage').value.trim());
    $('imgPreviewWrap').classList.toggle('hidden', !u);
    if (u) $('imgPreview').src = u;
});
$('imgPreview').addEventListener('error', () => $('imgPreviewWrap').classList.add('hidden'));

$('btnSubmit').addEventListener('click', async () => {
    const cfg = state.data.config;
    const payload = {
        title: $('inTitle').value.trim(), body: $('inBody').value.trim(), image: $('inImage').value.trim(),
        category: $('inCategory').value, duration: state.duration,
    };
    if (!payload.title || !payload.body) return toast(L('ui_err_required'), 'error');
    if (payload.image && !safeUrl(payload.image)) return toast(L('ui_err_image_https'), 'error');
    if (cfg.requireImage && !payload.image) return toast(L('ui_err_image_required'), 'error');
    $('btnSubmit').disabled = true;
    const res = await post('createNotice', payload);
    updateFee();
    if (res.ok) { closeModals(); refreshBoard(); }
});

/* my notices */
function renderMine() {
    const mine = state.data.notices.filter(n => n.mine);
    const warn = state.data.config.warnBefore;
    $('mineList').innerHTML = mine.length ? mine.map(n => {
        const left = n.expires_at - nowServer();
        const pct = Math.max(2, Math.min(100, (left / Math.max(1, n.expires_at - n.created_at)) * 100));
        const cls = left < warn ? 'stat-bad' : pct < 40 ? 'stat-warn' : 'stat-good';
        return `<div class="row">
            <div class="row-main">
                <div class="row-title">${esc(n.title)}</div>
                <div class="row-desc">${esc(catLabel(state.data.config, n.category))} &middot; ${esc(L('ui_expires_in_lc', timeLeft(n.expires_at)))}</div>
                <div class="bar"><div class="${cls}" style="width:${pct}%"></div></div>
            </div>
            <div class="row-actions">
                <button class="wood-btn small" data-renew="${n.id}">${esc(L('ui_renew'))}</button>
                <button class="wood-btn small muted danger" data-del="${n.id}">${esc(L('ui_remove'))}</button>
            </div></div>`;
    }).join('') : `<div class="empty">${esc(L('ui_none_mine', state.data.config.maxNotices))}</div>`;

    $('mineList').querySelectorAll('[data-renew]').forEach(b => b.addEventListener('click', () => {
        const id = Number(b.dataset.renew);
        askDuration(L('ui_renew_title'), state.data.config.durations, async (dur) => {
            const r = await post('renewNotice', { id, duration: dur });
            if (r.ok) { await refreshBoard(); renderMine(); openModal('mineModal'); }
        }, () => openModal('mineModal'));
    }));
    $('mineList').querySelectorAll('[data-del]').forEach(b => b.addEventListener('click', () => {
        const id = Number(b.dataset.del);
        askConfirm(L('ui_confirm_remove'), async () => {
            const r = await post('deleteOwnNotice', { id });
            if (r.ok) await refreshBoard();
            renderMine(); openModal('mineModal');
        }, () => openModal('mineModal'));
    }));
}
$('btnMine').addEventListener('click', () => { renderMine(); openModal('mineModal'); });

/* ---------- shared dialogs ---------- */
function askDuration(title, durations, cb, onCancel) {
    $('durationTitle').textContent = title;
    let picked = durations[0] && durations[0].id;
    renderDurationPicker($('durationList'), durations, picked, (id) => picked = id);
    durationCb = () => cb(picked);
    cancelHandlers.durationModal = onCancel;
    openModal('durationModal');
}
function askInput(title, value, cb) {
    $('inputTitle').textContent = title; $('inputValue').value = value || '';
    inputCb = cb; openModal('inputModal'); $('inputValue').focus();
}
function askConfirm(text, cb, onCancel) {
    $('confirmText').textContent = text; confirmCb = cb;
    cancelHandlers.confirmModal = onCancel;
    openModal('confirmModal');
}
document.querySelectorAll('#durationModal [data-close-modal], #confirmModal [data-close-modal]').forEach(b =>
    b.addEventListener('click', () => {
        const id = b.closest('.modal').id; const fn = cancelHandlers[id]; cancelHandlers[id] = null;
        if (fn) setTimeout(fn, 0);
    }));
$('btnDurationOk').addEventListener('click', () => { cancelHandlers.durationModal = null; closeModals(); durationCb && durationCb(); });
$('btnInputOk').addEventListener('click', () => { const v = $('inputValue').value.trim(); closeModals(); inputCb && inputCb(v); });
$('btnConfirmOk').addEventListener('click', () => { cancelHandlers.confirmModal = null; closeModals(); confirmCb && confirmCb(); });

/* ---------- admin ---------- */
let adminTab = 'boards';
function setAdminData(data) {
    state.admin = data;
    const sel = $('adminTown'), prev = sel.value || 'all';
    sel.classList.toggle('hidden', !data.separateTowns);
    sel.innerHTML = `<option value="all">${esc(L('ui_all_towns'))}</option>` + data.config.towns.map(t => `<option value="${esc(t.id)}">${esc(t.label)}</option>`).join('');
    sel.value = [...sel.options].some(o => o.value === prev) ? prev : 'all';
    state.clockOffset = data.now - Math.floor(Date.now() / 1000);
    renderAdmin();
}
async function refreshAdmin() {
    const d = await post('refreshAdmin');
    if (d && d.boards) setAdminData(d);
}
document.querySelectorAll('[data-admintab]').forEach(t => t.addEventListener('click', () => {
    adminTab = t.dataset.admintab;
    document.querySelectorAll('[data-admintab]').forEach(x => x.classList.toggle('active', x === t));
    renderAdmin();
}));

$('adminTown').addEventListener('change', () => renderAdmin());
function renderAdmin() {
    const a0 = state.admin, tf = $('adminTown').value || 'all';
    const a = { ...a0,
        boards: a0.boards.filter(b => tf === 'all' || b.town === tf),
        notices: a0.notices.filter(n => tf === 'all' || n.town === tf || !n.town) };
    $('adminBoards').classList.toggle('hidden', adminTab !== 'boards');
    $('adminNotices').classList.toggle('hidden', adminTab !== 'notices');
    $('btnPlace').classList.toggle('hidden', adminTab !== 'boards');

    $('adminBoards').innerHTML = a.boards.length ? a.boards.map(b => `<div class="row">
        <div class="badge">&#9873;</div>
        <div class="row-main"><div class="row-title">#${b.id} &middot; ${esc(b.label)}</div>
        <div class="row-desc">${esc(townLabel(a.config, b.town))}</div>
        <div class="row-desc">${Number(b.x).toFixed(2)}, ${Number(b.y).toFixed(2)}, ${Number(b.z).toFixed(2)} &middot; ${esc(L('ui_heading'))} ${Number(b.heading).toFixed(1)}</div></div>
        <div class="row-actions">
            <button class="wood-btn small" data-tp="${b.id}">${esc(L('ui_teleport'))}</button>
            <button class="wood-btn small" data-rename="${b.id}">${esc(L('ui_rename'))}</button>
            <button class="wood-btn small muted danger" data-delboard="${b.id}">${esc(L('ui_delete'))}</button>
        </div></div>`).join('')
        : `<div class="empty">${esc(L('ui_no_boards'))}</div>`;

    $('adminNotices').innerHTML = a.notices.length ? a.notices.map(n => {
        const img = safeUrl(n.image);
        return `<div class="row">
        <div class="badge" ${img ? `style="background-image:url('${esc(img)}')"` : ''}>${img ? '' : '&#10022;'}</div>
        <div class="row-main"><div class="row-title">${esc(n.title)}</div>
        <div class="row-desc">${esc(townLabel(a.config, n.town))} &middot; ${esc(catLabel(a.config, n.category))} &middot; ${esc(n.author)} (${esc(n.citizenid)}) &middot; ${esc(L('ui_expires_in_lc', timeLeft(n.expires_at)))}</div></div>
        <div class="row-actions">
            <button class="wood-btn small" data-view="${n.id}">${esc(L('ui_view'))}</button>
            <button class="wood-btn small" data-extend="${n.id}">${esc(L('ui_extend'))}</button>
            <button class="wood-btn small muted danger" data-delnotice="${n.id}">${esc(L('ui_delete'))}</button>
        </div></div>`;
    }).join('') : `<div class="empty">${esc(L('ui_no_notices'))}</div>`;

    const on = (sel, fn) => document.querySelectorAll(sel).forEach(b => b.addEventListener('click', () => fn(Number(Object.values(b.dataset)[0]))));
    on('[data-tp]', (id) => { $('app').classList.add('hidden'); post('adminTeleport', { id }); });
    on('[data-rename]', (id) => {
        const b = a.boards.find(x => x.id === id);
        askInput(L('ui_rename_board'), b && b.label, async (label) => { if (label && (await post('adminRenameBoard', { id, label })).ok) refreshAdmin(); });
    });
    on('[data-delboard]', (id) => askConfirm(L('ui_confirm_delete_board', id), async () => { await post('adminDeleteBoard', { id }); refreshAdmin(); }));
    on('[data-delnotice]', (id) => askConfirm(L('ui_confirm_delete_notice'), async () => { await post('adminDeleteNotice', { id }); refreshAdmin(); }));
    on('[data-extend]', (id) => askDuration(L('ui_extend_title'), a.config.durations.map(d => ({ ...d, price: 0 })), async (dur) => {
        if ((await post('adminExtendNotice', { id, duration: dur })).ok) refreshAdmin();
    }));
    on('[data-view]', (id) => {
        const n = a.notices.find(x => x.id === id); if (!n) return;
        state.data = { notices: a0.notices, config: a.config };
        viewNotice(id);
    });
}

$('btnPlace').addEventListener('click', () => askInput(L('ui_new_board_name'), L('ui_board_title'), (label) => {
    $('app').classList.add('hidden');
    post('adminPlaceBoard', { label: label || L('ui_board_title') });
}));
