const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'rsg-noticeboard';
const $ = (id) => document.getElementById(id);
const post = (name, data = {}) => fetch(`https://${RES}/${name}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data)
}).then(r => r.json()).catch(() => ({}));

const state = {
    data: null, admin: null, mine: null, clockOffset: 0,
    query: { category: 'all', search: '', sort: 'new', page: 1 },
    duration: null, featured: false, edit: null, view: null,
};
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
const fmtDate = (ts) => new Date(ts * 1000).toLocaleDateString();
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

/* ---------- dropdowns (pure HTML; native selects can crash RedM's CEF) ---------- */
function closeDd() { document.querySelectorAll('.dd.open').forEach(d => { d.classList.remove('open'); d.querySelector('.dd-menu').classList.add('hidden'); }); }
document.addEventListener('mousedown', (e) => { if (!e.target.closest('.dd')) closeDd(); });

function setupDd(el, options, value, onChange) {
    const cur = options.find(o => o.value === value) || options[0];
    el.dataset.value = cur ? cur.value : '';
    el.innerHTML = `<div class="dd-value">${esc(cur ? cur.label : '')}</div><div class="dd-arrow">&#9662;</div>
        <div class="dd-menu hidden">${options.map(o => `<div class="dd-opt ${cur && o.value === cur.value ? 'sel' : ''}" data-v="${esc(o.value)}">${esc(o.label)}</div>`).join('')}</div>`;
    const menu = el.querySelector('.dd-menu');
    el.querySelector('.dd-value').onclick = () => {
        const open = !el.classList.contains('open');
        closeDd();
        if (open) { el.classList.add('open'); menu.classList.remove('hidden'); }
    };
    // pick on mousedown so nothing steals the click first
    menu.querySelectorAll('.dd-opt').forEach(o => o.addEventListener('mousedown', (e) => {
        e.preventDefault();
        const opt = options.find(x => x.value === o.dataset.v);
        setupDd(el, options, o.dataset.v, onChange);
        if (onChange && opt) onChange(opt.value);
    }));
}

/* ---------- open / close ---------- */
window.addEventListener('message', (e) => {
    const { action, data, locale } = e.data || {};
    if (locale) { LOCALE = locale; applyLocale(); }
    if (action === 'openBoard') { setBoardData(data); show('board'); }
    if (action === 'openAdmin') { setAdminData(data); show('admin'); }
    if (action === 'expiryRenew') openExpiryRenew(data);
});

function show(which) {
    closeDd();
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
    closeDd();
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

/* ---------- player board (one page at a time, searchable) ---------- */
function setBoardData(data) {
    state.data = data;
    state.clockOffset = data.now - Math.floor(Date.now() / 1000);
    state.query = { category: 'all', search: '', sort: 'new', page: 1 };
    $('searchBox').value = '';
    $('searchBox').maxLength = data.config.searchMax || 40;
    setupDd($('sortDd'), [
        { value: 'new', label: L('ui_sort_new') },
        { value: 'expiring', label: L('ui_sort_expiring') },
        { value: 'title', label: L('ui_sort_title') },
    ], 'new', (v) => { state.query.sort = v; state.query.page = 1; loadPage(); });
    $('boardTown').textContent = data.town ? L('ui_board_sub_town', data.town) : L('ui_board_sub');
    renderTabs(); renderGrid(); renderPager();
}

async function loadPage() {
    const d = await post('getNotices', state.query);
    if (!d || !d.notices) return;
    Object.assign(state.data, d);
    state.query.page = d.page;
    state.clockOffset = d.now - Math.floor(Date.now() / 1000);
    renderTabs(); renderGrid(); renderPager();
}
const refreshBoard = loadPage;

let searchTimer;
$('searchBox').addEventListener('input', () => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => { state.query.search = $('searchBox').value.trim(); state.query.page = 1; loadPage(); }, 300);
});
$('btnPrev').addEventListener('click', () => { if (state.query.page > 1) { state.query.page--; loadPage(); } });
$('btnNext').addEventListener('click', () => { if (state.query.page < state.data.pages) { state.query.page++; loadPage(); } });

function renderTabs() {
    const cfg = state.data.config, counts = state.data.counts || {};
    const total = Object.values(counts).reduce((a, b) => a + b, 0);
    const tabs = [{ id: 'all', label: L('ui_all') }, ...cfg.categories];
    $('categoryTabs').innerHTML = tabs.map(c => {
        const n = c.id === 'all' ? total : (counts[c.id] || 0);
        return `<button class="tab ${state.query.category === c.id ? 'active' : ''}" data-cat="${esc(c.id)}">${esc(c.label)} (${n})</button>`;
    }).join('');
    $('categoryTabs').querySelectorAll('.tab').forEach(t => t.addEventListener('click', () => {
        state.query.category = t.dataset.cat; state.query.page = 1; loadPage();
    }));
}

function renderGrid() {
    const cfg = state.data.config;
    const list = state.data.notices;
    $('noticeEmpty').classList.toggle('hidden', list.length > 0);
    $('noticeEmpty').textContent = L(state.query.search ? 'ui_no_results' : 'ui_empty_board');
    $('noticeGrid').innerHTML = list.map(n => {
        const img = safeUrl(n.image);
        return `<div class="tile ${n.featured ? 'featured' : ''}" data-id="${n.id}">
            <div class="tile-img ${img ? '' : 'noimg'}" ${img ? `data-img="${esc(img)}" style="background-image:url('${esc(img)}')"` : ''}>${img ? '' : '&#10022;'}</div>
            <span class="pill">${esc(catLabel(cfg, n.category))}</span>
            ${n.featured ? `<span class="pill feat">&#9733; ${esc(L('ui_featured'))}</span>` : ''}
            ${n.mine ? `<span class="pill mine">${esc(L('ui_yours'))}</span>` : ''}
            <div class="tile-title">${n.pinned ? '&#9873; ' : ''}${esc(n.title)}</div>
            <div class="tile-meta"><span>${esc(n.author)}</span><span>${timeLeft(n.expires_at)}</span></div>
        </div>`;
    }).join('');
    $('noticeGrid').querySelectorAll('.tile').forEach(t => t.addEventListener('click', () => viewNotice(Number(t.dataset.id), cfg, list)));
    // swap broken poster images for the placeholder
    $('noticeGrid').querySelectorAll('.tile-img:not(.noimg)').forEach(el => {
        const img = new Image();
        img.onerror = () => { el.style.backgroundImage = ''; el.classList.add('noimg'); el.innerHTML = '&#10022;'; };
        img.src = el.dataset.img;
    });
}

function renderPager() {
    const d = state.data;
    $('pager').classList.toggle('hidden', d.pages <= 1);
    $('pageInfo').textContent = L('ui_page', d.page, d.pages);
    $('btnPrev').disabled = d.page <= 1;
    $('btnNext').disabled = d.page >= d.pages;
}

/* ---------- viewing a notice (the text is fetched when it is opened) ---------- */
async function viewNotice(id, cfg, list, admin) {
    const n = list.find(x => x.id === id);
    if (!n) return;
    const d = await post('getNotice', { id });
    if (!d || !d.id) { toast(L('ui_gone'), 'error'); return; }
    showNotice(n, cfg, d, admin);
}

function showNotice(n, cfg, d, admin) {
    state.view = { id: n.id, reminded: !!d.reminded, pin: d.pin || null };
    $('viewCat').textContent = catLabel(cfg, n.category);
    $('viewTitle').textContent = n.title;
    $('viewBody').textContent = d.body;
    $('viewAuthor').textContent = L('ui_posted_by', n.author) + (n.edited_at ? ` (${L('ui_edited')})` : '');
    $('viewExpires').textContent = L('ui_expires_in', timeLeft(n.expires_at));
    const img = safeUrl(n.image);
    $('viewImage').classList.toggle('hidden', !img);
    if (img) $('viewImage').src = img; else $('viewImage').removeAttribute('src');
    $('btnReport').classList.toggle('hidden', admin || d.mine || !cfg.reportReasons);
    $('btnRemind').classList.toggle('hidden', admin || d.mine || !cfg.canRemind);
    $('btnMap').classList.toggle('hidden', !d.pin);
    setRemindLabel();
    openModal('viewModal');
}
$('viewImage').addEventListener('error', () => $('viewImage').classList.add('hidden'));

function setRemindLabel() { $('btnRemind').textContent = L(state.view && state.view.reminded ? 'ui_remind_cancel' : 'ui_remind'); }
$('btnRemind').addEventListener('click', async () => {
    const r = await post('toggleReminder', { id: state.view.id });
    if (r.ok === 'on') state.view.reminded = true;
    else if (r.ok === 'off') state.view.reminded = false;
    setRemindLabel();
});
$('btnMap').addEventListener('click', () => { if (state.view.pin) post('setWaypoint', state.view.pin); });
$('btnReport').addEventListener('click', () => {
    const reasons = state.data.config.reportReasons || [];
    setupDd($('reportReason'), reasons.map(r => ({ value: r, label: L('ui_reason_' + r) })), reasons[0]);
    openModal('reportModal');
});
$('btnReportOk').addEventListener('click', async () => {
    const r = await post('reportNotice', { id: state.view.id, reason: $('reportReason').dataset.value });
    closeModals();
    if (r.ok) loadPage();
});

/* ---------- post / edit ---------- */
function renderDurationPicker(container, durations, selected, onPick) {
    container.innerHTML = durations.map(d =>
        `<div class="dur ${selected === d.id ? 'active' : ''}" data-id="${esc(d.id)}"><div class="d-label">${esc(d.label)}</div><div class="d-price">${d.price > 0 ? money(d.price) : esc(L('ui_free'))}</div></div>`).join('');
    container.querySelectorAll('.dur').forEach(el => el.addEventListener('click', () => {
        container.querySelectorAll('.dur').forEach(x => x.classList.remove('active'));
        el.classList.add('active'); onPick(el.dataset.id);
    }));
}

function updateFee() {
    const cfg = state.data.config;
    const d = cfg.durations.find(x => x.id === state.duration);
    const fee = state.edit ? 0 : (d ? d.price : 0) + (state.featured && cfg.featured ? cfg.featured : 0);
    $('feeValue').textContent = money(fee);
    $('cashValue').textContent = money(state.data.cash);
    $('feeValue').classList.toggle('over', fee > state.data.cash);
    $('btnSubmit').disabled = fee > state.data.cash; // can't afford it, don't let them try
}

// edit = null for a new notice, or { id, title, body, image, category }
function openCompose(edit) {
    const cfg = state.data.config;
    state.edit = edit; state.featured = false;
    $('createTitle').textContent = L(edit ? 'ui_edit_title' : 'ui_create_title');
    $('btnSubmit').textContent = L(edit ? 'ui_save' : 'ui_pin');
    $('inTitle').value = edit ? edit.title : ''; $('inBody').value = edit ? edit.body : ''; $('inImage').value = edit ? edit.image : '';
    $('inTitle').maxLength = cfg.titleMax; $('inBody').maxLength = cfg.bodyMax;
    const u = safeUrl($('inImage').value);
    $('imgPreviewWrap').classList.toggle('hidden', !u);
    if (u) $('imgPreview').src = u;
    setupDd($('inCategory'), cfg.categories.map(c => ({ value: c.id, label: c.label })),
        edit ? edit.category : (state.query.category !== 'all' ? state.query.category : null));
    state.duration = cfg.durations[0] && cfg.durations[0].id;
    renderDurationPicker($('durationPick'), cfg.durations, state.duration, (id) => { state.duration = id; updateFee(); });
    $('periodBlock').classList.toggle('hidden', !!edit);
    $('costLine').classList.toggle('hidden', !!edit);
    $('inFeatured').classList.toggle('hidden', !!edit || !cfg.featured);
    $('inFeatured').classList.remove('on');
    $('featLabel').textContent = L('ui_feature_opt', money(cfg.featured));
    updateCounts(); updateFee();
    openModal('createModal');
    $('inTitle').focus();
}

async function openEdit(n) {
    const d = await post('getNotice', { id: n.id });
    if (!d || !d.id) { toast(L('ui_gone'), 'error'); return; }
    openCompose({ id: n.id, title: n.title, body: d.body, image: n.image || '', category: n.category });
}

$('btnNew').addEventListener('click', () => openCompose(null));
$('inFeatured').addEventListener('click', () => {
    state.featured = !state.featured;
    $('inFeatured').classList.toggle('on', state.featured);
    updateFee();
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
        category: $('inCategory').dataset.value, duration: state.duration, featured: state.featured,
    };
    if (!payload.title || !payload.body) return toast(L('ui_err_required'), 'error');
    if (payload.image && !safeUrl(payload.image)) return toast(L('ui_err_image_https'), 'error');
    if (cfg.requireImage && !payload.image) return toast(L('ui_err_image_required'), 'error');
    $('btnSubmit').disabled = true;
    const editing = state.edit;
    const res = editing ? await post('editNotice', { ...payload, id: editing.id }) : await post('createNotice', payload);
    updateFee();
    if (!res.ok) return;
    closeModals();
    await loadPage();
    if (editing) openMine();
});

/* ---------- my notices ---------- */
async function openMine() {
    const d = await post('getMyNotices');
    if (!d || !d.notices) return;
    state.mine = d;
    renderMine();
    openModal('mineModal');
}

function renderMine() {
    const cfg = state.data.config, mine = state.mine.notices, warn = cfg.warnBefore;
    const now = nowServer();
    $('mineList').innerHTML = mine.length ? mine.map(n => {
        const left = n.expires_at - now;
        const pct = Math.max(2, Math.min(100, (left / Math.max(1, n.expires_at - n.created_at)) * 100));
        const cls = left < warn ? 'stat-bad' : pct < 40 ? 'stat-warn' : 'stat-good';
        const tags = (n.featured ? `<span class="tag">&#9733; ${esc(L('ui_featured'))}</span>` : '')
            + (n.pinned ? `<span class="tag">&#9873;</span>` : '')
            + (n.hidden ? `<span class="tag warn">${esc(L('ui_hidden'))}</span>` : '');
        return `<div class="row">
            <div class="row-main">
                <div class="row-title">${esc(n.title)} ${tags}</div>
                <div class="row-desc">${esc(catLabel(cfg, n.category))} &middot; ${esc(L('ui_expires_in_lc', timeLeft(n.expires_at)))}</div>
                <div class="bar"><div class="${cls}" style="width:${pct}%"></div></div>
            </div>
            <div class="row-actions">
                ${cfg.canEdit ? `<button class="wood-btn small" data-edit="${n.id}">${esc(L('ui_edit'))}</button>` : ''}
                <button class="wood-btn small" data-renew="${n.id}">${esc(L('ui_renew'))}</button>
                ${cfg.featured && !n.featured ? `<button class="wood-btn small" data-feature="${n.id}">${esc(L('ui_feature'))}</button>` : ''}
                ${cfg.canPin ? `<button class="wood-btn small" data-pin="${n.id}">${esc(L(n.pinned ? 'ui_pin_clear' : 'ui_pin_here'))}</button>` : ''}
                <button class="wood-btn small muted danger" data-del="${n.id}">${esc(L('ui_remove'))}</button>
            </div></div>`;
    }).join('') : `<div class="empty">${esc(L('ui_none_mine', cfg.maxNotices))}</div>`;

    const find = (id) => mine.find(x => x.id === id);
    const each = (sel, fn) => $('mineList').querySelectorAll(sel).forEach(b => b.addEventListener('click', () => fn(Number(Object.values(b.dataset)[0]))));
    each('[data-edit]', (id) => openEdit(find(id)));
    each('[data-renew]', (id) => askDuration(L('ui_renew_title'), cfg.durations, async (dur) => {
        const r = await post('renewNotice', { id, duration: dur });
        if (r.ok) await loadPage();
        openMine();
    }, () => openModal('mineModal')));
    each('[data-feature]', (id) => askConfirm(L('ui_confirm_feature', money(cfg.featured)), async () => {
        const r = await post('featureNotice', { id });
        if (r.ok) await loadPage();
        openMine();
    }, () => openModal('mineModal')));
    each('[data-pin]', async (id) => {
        const n = find(id);
        await post('setPin', { id, enable: !n.pinned });
        openMine();
    });
    each('[data-del]', (id) => askConfirm(L('ui_confirm_remove'), async () => {
        const r = await post('deleteOwnNotice', { id });
        if (r.ok) await loadPage();
        openMine();
    }, () => openModal('mineModal')));
}
$('btnMine').addEventListener('click', openMine);

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
$('inputValue').addEventListener('keydown', (e) => { if (e.key === 'Enter') $('btnInputOk').click(); });
$('btnConfirmOk').addEventListener('click', () => { cancelHandlers.confirmModal = null; closeModals(); confirmCb && confirmCb(); });

/* ---------- expiry renew prompt (opened from the client warning) ---------- */
function openExpiryRenew(d) {
    show('none');
    askConfirm(d.text, () => {
        askDuration(d.chooseTitle, d.durations || [], async (dur) => {
            await post('renewNotice', { id: d.id, duration: dur });
            closeAll();
        }, closeAll);
    }, closeAll);
}

/* ---------- admin ---------- */
let adminTab = 'boards';
function setAdminData(data) {
    state.admin = data;
    const sel = $('adminTown'), prev = sel.dataset.value || 'all';
    sel.classList.toggle('hidden', !data.separateTowns);
    setupDd(sel, [{ value: 'all', label: L('ui_all_towns') }, ...data.config.towns.map(t => ({ value: t.id, label: t.label }))], prev, () => renderAdmin());
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

const tagHtml = (n) => (n.featured ? `<span class="tag">&#9733;</span>` : '') + (n.hidden ? `<span class="tag warn">${esc(L('ui_hidden'))}</span>` : '');

function renderAdmin() {
    const a0 = state.admin, tf = $('adminTown').dataset.value || 'all';
    const inTown = (x) => tf === 'all' || x.town === tf || !x.town;
    const a = { ...a0,
        boards: a0.boards.filter(b => tf === 'all' || b.town === tf),
        notices: a0.notices.filter(inTown),
        reports: a0.reports.filter(inTown) };
    const cfg = a.config;
    $('tabReports').textContent = `${L('ui_tab_reports')} (${a.reports.length})`;
    $('tabBans').textContent = `${L('ui_tab_bans')} (${a.bans.length})`;
    for (const t of ['boards', 'notices', 'reports', 'bans']) $('admin' + t[0].toUpperCase() + t.slice(1)).classList.toggle('hidden', adminTab !== t);
    $('btnPlace').classList.toggle('hidden', adminTab !== 'boards');
    $('adminTown').classList.toggle('hidden', !a0.separateTowns || adminTab === 'bans');

    $('adminBoards').innerHTML = a.boards.length ? a.boards.map(b => `<div class="row">
        <div class="badge">&#9873;</div>
        <div class="row-main"><div class="row-title">#${b.id} &middot; ${esc(b.label)}</div>
        <div class="row-desc">${esc(townLabel(cfg, b.town))}</div>
        <div class="row-desc">${Number(b.x).toFixed(2)}, ${Number(b.y).toFixed(2)}, ${Number(b.z).toFixed(2)} &middot; ${esc(L('ui_heading'))} ${Number(b.heading).toFixed(1)}</div></div>
        <div class="row-actions">
            <button class="wood-btn small" data-tp="${b.id}">${esc(L('ui_teleport'))}</button>
            <button class="wood-btn small" data-rename="${b.id}">${esc(L('ui_rename'))}</button>
            <button class="wood-btn small muted danger" data-delboard="${b.id}">${esc(L('ui_delete'))}</button>
        </div></div>`).join('')
        : `<div class="empty">${esc(L('ui_no_boards'))}</div>`;

    const badge = (n) => { const img = safeUrl(n.image); return `<div class="badge" ${img ? `style="background-image:url('${esc(img)}')"` : ''}>${img ? '' : '&#10022;'}</div>`; };

    $('adminNotices').innerHTML = a.notices.length ? a.notices.map(n => `<div class="row">
        ${badge(n)}
        <div class="row-main"><div class="row-title">${esc(n.title)} ${tagHtml(n)}</div>
        <div class="row-desc">${esc(townLabel(cfg, n.town))} &middot; ${esc(catLabel(cfg, n.category))} &middot; ${esc(n.author)} (${esc(n.citizenid)}) &middot; ${esc(L('ui_expires_in_lc', timeLeft(n.expires_at)))}</div></div>
        <div class="row-actions">
            <button class="wood-btn small" data-view="${n.id}">${esc(L('ui_view'))}</button>
            <button class="wood-btn small" data-extend="${n.id}">${esc(L('ui_extend'))}</button>
            <button class="wood-btn small muted danger" data-banposter="${n.id}">${esc(L('ui_ban'))}</button>
            <button class="wood-btn small muted danger" data-delnotice="${n.id}">${esc(L('ui_delete'))}</button>
        </div></div>`).join('')
        : `<div class="empty">${esc(L('ui_no_notices'))}</div>`;

    $('adminReports').innerHTML = a.reports.length ? a.reports.map(n => `<div class="row">
        ${badge(n)}
        <div class="row-main"><div class="row-title">${esc(n.title)} ${tagHtml(n)}</div>
        <div class="row-desc">${esc(L('ui_reports_n', n.reports))} &middot; ${esc(String(n.reasons || '').split(',').map(r => L('ui_reason_' + r)).join(', '))}</div>
        <div class="row-desc">${esc(n.author)} (${esc(n.citizenid)}) &middot; ${esc(townLabel(cfg, n.town))}</div></div>
        <div class="row-actions">
            <button class="wood-btn small" data-view="${n.id}">${esc(L('ui_view'))}</button>
            <button class="wood-btn small" data-dismiss="${n.id}">${esc(L('ui_dismiss'))}</button>
            <button class="wood-btn small muted danger" data-delnotice="${n.id}">${esc(L('ui_remove'))}</button>
            <button class="wood-btn small muted danger" data-removeban="${n.id}">${esc(L('ui_remove_ban'))}</button>
        </div></div>`).join('')
        : `<div class="empty">${esc(L('ui_no_reports'))}</div>`;

    $('adminBans').innerHTML = a.bans.length ? a.bans.map(b => `<div class="row">
        <div class="badge">&#9888;</div>
        <div class="row-main"><div class="row-title">${esc(b.name)} (${esc(b.citizenid)})</div>
        <div class="row-desc">${esc(b.reason)} &middot; ${esc(L('ui_ban_until', fmtDate(b.expires_at)))}</div></div>
        <div class="row-actions"><button class="wood-btn small" data-unban="${esc(b.citizenid)}">${esc(L('ui_unban'))}</button></div></div>`).join('')
        : `<div class="empty">${esc(L('ui_no_bans'))}</div>`;

    const on = (sel, fn) => document.querySelectorAll(sel).forEach(b => b.addEventListener('click', () => fn(Number(Object.values(b.dataset)[0]))));
    const act = (name, payload) => post(name, payload).then(() => refreshAdmin());
    on('[data-tp]', (id) => { $('app').classList.add('hidden'); post('adminTeleport', { id }); });
    on('[data-rename]', (id) => {
        const b = a.boards.find(x => x.id === id);
        askInput(L('ui_rename_board'), b && b.label, async (label) => { if (label && (await post('adminRenameBoard', { id, label })).ok) refreshAdmin(); });
    });
    on('[data-delboard]', (id) => askConfirm(L('ui_confirm_delete_board', id), () => act('adminDeleteBoard', { id })));
    on('[data-delnotice]', (id) => askConfirm(L('ui_confirm_delete_notice'), () => act('adminDeleteNotice', { id })));
    on('[data-extend]', (id) => askDuration(L('ui_extend_title'), cfg.durations.map(d => ({ ...d, price: 0 })), async (dur) => {
        if ((await post('adminExtendNotice', { id, duration: dur })).ok) refreshAdmin();
    }));
    on('[data-view]', (id) => viewNotice(id, cfg, a0.notices.concat(a0.reports), true));
    on('[data-dismiss]', (id) => act('adminDismissReports', { id }));
    on('[data-banposter]', (id) => askConfirm(L('ui_confirm_ban', cfg.banDays), () => act('adminBanPoster', { id })));
    on('[data-removeban]', (id) => askConfirm(L('ui_confirm_ban', cfg.banDays), () => act('adminRemoveReported', { id, ban: true })));
    document.querySelectorAll('[data-unban]').forEach(b => b.addEventListener('click', () => act('adminUnban', { citizenid: b.dataset.unban })));
}

$('btnPlace').addEventListener('click', () => askInput(L('ui_new_board_name'), L('ui_board_title'), (label) => {
    $('app').classList.add('hidden');
    post('adminPlaceBoard', { label: label || L('ui_board_title') });
}));
