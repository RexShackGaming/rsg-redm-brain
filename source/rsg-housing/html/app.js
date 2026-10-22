const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-housing';
const $ = (id) => document.getElementById(id);

let S = {};          // locale strings
let house = null;    // { id, name }
let status = null;   // server status
let view = 'main';
let pendingConfirm = null;
let tiers = [];
let SEARCH_MIN = 2;

const ICONS = {
    guests: '<svg viewBox="0 0 24 24"><circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c0-3.6 2.9-6 6.5-6s6.5 2.4 6.5 6"/><circle cx="17" cy="9" r="2.5"/><path d="M16 14.2c3 .2 5.5 2.2 5.5 5.8"/></svg>',
    storage: '<svg viewBox="0 0 24 24"><rect x="3" y="7" width="18" height="13" rx="1"/><path d="M3 11h18M10 15h4M6 7l2-3h8l2 3"/></svg>',
    outfits: '<svg viewBox="0 0 24 24"><path d="M8 4l4 3 4-3 5 4-3 3v9H6v-9L3 8z"/></svg>',
    mailbox: '<svg viewBox="0 0 24 24"><rect x="3" y="5" width="18" height="14" rx="1"/><path d="M3 6l9 7 9-7"/></svg>',
    home: '<svg viewBox="0 0 24 24"><path d="M3 11l9-7 9 7"/><path d="M5 10v10h14V10"/><path d="M10 20v-6h4v6"/></svg>',
    rename: '<svg viewBox="0 0 24 24"><path d="M4 20h4L19 9l-4-4L4 16z"/><path d="M13.5 6.5l4 4"/></svg>',
    leave: '<svg viewBox="0 0 24 24"><path d="M14 4h5v16h-5M10 8l-4 4 4 4M6 12h10"/></svg>',
    person: '<svg viewBox="0 0 24 24"><circle cx="12" cy="8" r="4"/><path d="M4 21c0-4.4 3.6-7 8-7s8 2.6 8 7"/></svg>'
};

/* helpers */
function post(name, data = {}) {
    return fetch(`https://${resource}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function fmt(str, ...args) {
    let i = 0;
    return String(str ?? '').replace(/%s/g, () => (args[i++] ?? ''));
}

function escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = String(str ?? '');
    return div.innerHTML;
}

function richText(str) {
    return escapeHtml(str).replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
}

function money(n) {
    return '$' + Number(n || 0).toLocaleString('en-US');
}

function applyStrings() {
    document.querySelectorAll('#app [data-str], #modal [data-str]').forEach((el) => {
        el.textContent = S[el.dataset.str] || el.dataset.str;
    });
    document.querySelectorAll('#app [data-title]').forEach((el) => { el.title = S[el.dataset.title] || ''; });
    $('guest-input').placeholder = S.ui_search_placeholder || '';
}

/* views */
function showView(name) {
    if (name !== view) clearSearch();
    view = name;
    ['rent', 'main', 'guests', 'wardrobe', 'mailbox', 'storage'].forEach((v) => $('view-' + v).classList.toggle('hidden', v !== name));
    $('btn-back').classList.toggle('hidden', !['guests', 'wardrobe', 'mailbox', 'storage'].includes(name));
    render();
}

function displayName() {
    if (status && status.customName) return status.customName;
    return house.defaultName || house.name;
}

function render() {
    if (!house || !status) return;
    $('house-name').textContent = displayName();

    if (!status.rented) {
        $('house-sub').textContent = S.ui_vacant;
        $('rent-price').textContent = money(status.rent);
        $('rent-terms').textContent = fmt(S.ui_rent_terms, status.grace ?? '');
        return;
    }

    const isTenant = status.access === 'tenant';
    $('house-sub').textContent = isTenant ? S.ui_tenant : S.ui_guest;

    if (view === 'guests') return renderGuests();
    if (view === 'storage') return renderStorage();
    if (view === 'wardrobe' || view === 'mailbox') return;

    // rent card (tenant only)
    $('rent-card').classList.toggle('hidden', !isTenant);
    if (isTenant) renderRentCard();

    const rows = [];
    if (isTenant) {
        rows.push({ key: 'home', icon: 'home', title: S.ui_home_title, desc: S.ui_home_desc, toggle: status.home === true });
        rows.push({ key: 'guests', icon: 'guests', title: S.menu_guests_title, desc: S.menu_guests_desc, chev: true, count: (status.guests || []).length });
    }
    // guests only see what the tenant has allowed
    const can = (perm) => isTenant || (status.perms && status.perms[perm]);
    if (can('storage')) rows.push({ key: 'storage', icon: 'storage', title: S.menu_storage_title, desc: S.menu_storage_desc, chev: true });
    if (can('wardrobe')) rows.push({ key: 'outfits', icon: 'outfits', title: S.menu_outfits_title, desc: S.menu_outfits_desc });
    if (can('mailbox')) rows.push({ key: 'mailbox', icon: 'mailbox', title: S.menu_mailbox_title, desc: S.menu_mailbox_desc, chev: true, unread: status.unread });
    if (rows.length === 0) {
        $('main-rows').innerHTML = `<div class="muted empty">${escapeHtml(S.ui_no_permission)}</div>`;
        return;
    }
    if (isTenant) {
        rows.push({ key: 'rename', icon: 'rename', title: S.ui_rename_title, desc: S.ui_rename_desc });
        rows.push({ key: 'leave', icon: 'leave', title: S.end_tenancy_title, desc: S.end_tenancy_desc, danger: true });
    }

    $('main-rows').innerHTML = rows.map((r) => `
        <div class="row${r.danger ? ' danger' : ''}" data-key="${r.key}">
            <div class="badge">${ICONS[r.icon]}</div>
            <div class="row-body">
                <div class="row-title">${escapeHtml(r.title)}</div>
                <div class="row-desc">${escapeHtml(r.desc)}</div>
            </div>
            ${r.toggle !== undefined ? `<span class="switch${r.toggle ? ' on' : ''}"><span class="switch-label">${escapeHtml(r.toggle ? S.ui_home_on : S.ui_home_off)}</span><span class="knob"></span></span>` : ''}
            ${r.count !== undefined ? `<span class="pill">${r.count}</span>` : ''}
            ${r.unread ? `<span class="pill warn">${r.unread} ${escapeHtml(S.ui_new)}</span>` : ''}
            ${r.chev ? '<span class="chev">&#10095;</span>' : ''}
        </div>`).join('');
}

function renderRentCard() {
    const hours = Number(status.hoursLeft || 0);
    const days = Math.floor(Math.abs(hours) / 24);
    const pill = $('rent-pill');
    const bar = $('rent-bar');

    let cls;
    if (status.overdue) {
        cls = 'bad';
        $('rent-line').textContent = fmt(S.ui_overdue_since, status.due);
        pill.textContent = fmt(S.ui_overdue_days, Math.max(0, (status.grace || 0) - days));
    } else {
        cls = days >= 7 ? 'good' : 'warn';
        $('rent-line').textContent = fmt(S.ui_paid_until, status.due);
        pill.textContent = fmt(S.ui_days_left, days);
    }

    pill.className = 'pill ' + cls;
    bar.className = 'bar-fill stat-' + cls;
    const pct = status.overdue ? 100 : Math.max(3, Math.min(100, (hours / (31 * 24)) * 100));
    bar.style.width = pct + '%';

    $('rent-amount').textContent = money(status.rent) + ' ' + (S.ui_per_month || '').toLowerCase();

    const pay = $('btn-pay');
    pay.disabled = !status.canPay;
    pay.textContent = status.canPay ? fmt(S.ui_pay_rent, money(status.rent)) : S.ui_paid_ahead;
}

function renderGuests() {
    const guests = status.guests || [];
    if (guests.length === 0) {
        $('guest-rows').innerHTML = `<div class="muted empty">${escapeHtml(S.ui_no_guests)}</div>`;
        return;
    }
    const perms = ['doors', 'storage', 'wardrobe', 'mailbox'];
    $('guest-rows').innerHTML = guests.map((g) => `
        <div class="guest-card">
            <div class="row static">
                <div class="badge">${ICONS.person}</div>
                <div class="row-body">
                    <div class="row-title">${escapeHtml(g.name || g.citizenid)}</div>
                    <div class="row-desc">${escapeHtml(g.citizenid)}</div>
                </div>
                <button class="wood-btn muted small" data-remove="${escapeHtml(g.citizenid)}" data-name="${escapeHtml(g.name || g.citizenid)}">${escapeHtml(S.ui_remove)}</button>
            </div>
            <div class="perm-row">
                <span class="perm-label">${escapeHtml(S.ui_guest_access)}</span>
                ${perms.map((p) => {
                    const on = !!(g.perms && g.perms[p]);
                    return `<button class="perm-chip${on ? ' on' : ''}" data-perm="${p}" data-cid="${escapeHtml(g.citizenid)}" data-on="${on ? 1 : 0}">${escapeHtml(S['perm_' + p] || p)}</button>`;
                }).join('')}
            </div>
        </div>`).join('');
}

/* modal */
function confirmBox(title, text, onConfirm, input) {
    $('modal-title').textContent = title;
    $('modal-text').innerHTML = richText(text);
    pendingConfirm = onConfirm;

    const field = $('modal-input');
    field.classList.toggle('hidden', !input);
    $('modal-confirm').textContent = input ? (S.ui_save || '') : (S.ui_confirm || '');
    $('modal').classList.remove('hidden');
    if (input) {
        field.value = input.value || '';
        field.placeholder = input.placeholder || '';
        setTimeout(() => { field.focus(); field.select(); }, 30);
    }
}

function closeModal() {
    $('modal').classList.add('hidden');
    pendingConfirm = null;
}

/* toasts */
function toast(message, type = 'inform', label) {
    const el = document.createElement('div');
    el.className = 'toast ' + type;
    el.innerHTML = `<div class="label">${escapeHtml(label || (house ? displayName() : (S.ui_house || '')))}</div><div class="msg">${escapeHtml(message)}</div>`;
    $('toasts').appendChild(el);
    setTimeout(() => {
        el.classList.add('out');
        setTimeout(() => el.remove(), 260);
    }, 4500);
}

/* open / close */
function open(data) {
    S = data.strings || S;
    tiers = data.tiers || tiers;
    SEARCH_MIN = data.searchMin || SEARCH_MIN;
    house = data.house;
    status = data.status;
    applyStrings();
    closeModal();
    $('app').classList.remove('hidden');
    showView(status.rented ? 'main' : 'rent');
}

function close() {
    $('app').classList.add('hidden');
    closeModal();
    house = null;
    status = null;
}

function requestClose() {
    post('close');
}

/* events */
window.addEventListener('message', (e) => {
    const data = e.data || {};
    switch (data.action) {
        case 'open': open(data); break;
        case 'update':
            if (!house) return;
            status = data.status;
            if (!status.rented) showView('rent');
            else if (view === 'rent') showView('main');
            else render();
            break;
        case 'toast': toast(data.message, data.type); break;
        case 'close': close(); break;
        case 'adminOpen': adminOpen(data); break;
        case 'adminClose': adminClose(); break;
    }
});

$('btn-close').addEventListener('click', requestClose);
$('btn-back').addEventListener('click', () => {
    if (view === 'mailbox' && !$('mail-letter').classList.contains('hidden')) return showMailList();
    showView('main');
});
$('modal-cancel').addEventListener('click', closeModal);
$('modal-confirm').addEventListener('click', () => {
    const fn = pendingConfirm;
    closeModal();
    if (fn) fn($('modal-input').value);
});

$('modal-input').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') $('modal-confirm').click();
});

$('btn-rent').addEventListener('click', () => {
    confirmBox(fmt(S.confirm_rent_header, house.name), fmt(S.confirm_rent_content, money(status.rent).slice(1), status.grace ?? 3),
        () => post('action', { action: 'rent' }));
});

$('btn-pay').addEventListener('click', () => {
    if (!status.canPay) return;
    confirmBox(S.ui_confirm_pay, fmt(S.ui_confirm_pay_content, money(status.rent)),
        () => post('action', { action: 'payRent' }));
});

$('main-rows').addEventListener('click', (e) => {
    const row = e.target.closest('.row');
    if (!row) return;
    const key = row.dataset.key;
    if (key === 'guests') return showView('guests');
    if (key === 'outfits') return openWardrobe();
    if (key === 'storage') return showView('storage');
    if (key === 'home') return post('action', { action: 'home', on: !status.home });
    if (key === 'mailbox') return openMailbox();
    if (key === 'rename') {
        return confirmBox(S.ui_rename_title, fmt(S.ui_rename_content, house.defaultName || house.name),
            (value) => post('action', { action: 'rename', name: String(value || '').trim().slice(0, 30) }),
            { value: status.customName || '', placeholder: S.ui_rename_placeholder });
    }
    if (key === 'leave') {
        return confirmBox(fmt(S.confirm_end_header, displayName()), S.confirm_end_content,
            () => post('action', { action: 'endTenancy' }));
    }
});

/* guest search */
let searchTimer = null;
let searchSeq = 0;

function renderSearch(results, query) {
    const box = $('search-rows');
    if (query.length < SEARCH_MIN) {
        box.innerHTML = query.length ? `<div class="muted">${escapeHtml(fmt(S.ui_search_hint, SEARCH_MIN))}</div>` : '';
        return;
    }
    if (!results.length) {
        box.innerHTML = `<div class="muted">${escapeHtml(S.ui_search_none)}</div>`;
        return;
    }
    box.innerHTML = results.map((r) => `
        <div class="row static">
            <div class="badge">${ICONS.person}</div>
            <div class="row-body">
                <div class="row-title">${escapeHtml(r.name)}</div>
                <div class="row-desc">${escapeHtml(r.citizenid)}</div>
            </div>
            <button class="wood-btn small" data-add="${escapeHtml(r.citizenid)}">${escapeHtml(S.ui_add)}</button>
        </div>`).join('');
}

async function runSearch(query) {
    const seq = ++searchSeq;
    try {
        const res = await fetch(`https://${resource}/searchPlayers`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({ query })
        });
        const data = await res.json();
        if (seq !== searchSeq) return; // a newer search has started
        if (data.skipped) { searchTimer = setTimeout(() => runSearch(query), 350); return; }
        renderSearch(data.results || [], query);
    } catch (e) { /* ignore */ }
}

function clearSearch() {
    clearTimeout(searchTimer);
    searchSeq++;
    $('guest-input').value = '';
    $('search-rows').innerHTML = '';
}

$('guest-input').addEventListener('input', () => {
    const query = $('guest-input').value.trim();
    clearTimeout(searchTimer);
    if (query.length < SEARCH_MIN) {
        searchSeq++;
        return renderSearch([], query);
    }
    searchTimer = setTimeout(() => runSearch(query), 300);
});

$('search-rows').addEventListener('click', (e) => {
    const btn = e.target.closest('[data-add]');
    if (!btn) return;
    post('action', { action: 'addGuest', citizenid: btn.dataset.add });
    clearSearch();
});

$('guest-rows').addEventListener('click', (e) => {
    const chip = e.target.closest('[data-perm]');
    if (chip) {
        const allowed = chip.dataset.on !== '1';
        chip.classList.toggle('on', allowed);  // instant feedback, the status refresh confirms it
        chip.dataset.on = allowed ? '1' : '0';
        return post('action', { action: 'setGuestPerm', citizenid: chip.dataset.cid, perm: chip.dataset.perm, allowed });
    }
    const btn = e.target.closest('[data-remove]');
    if (!btn) return;
    const cid = btn.dataset.remove;
    confirmBox(S.ui_confirm_remove, fmt(S.ui_confirm_remove_content, btn.dataset.name),
        () => post('action', { action: 'removeGuest', citizenid: cid }));
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !$('admin').classList.contains('hidden')) {
        if (!$('modal').classList.contains('hidden')) return closeModal();
        if (admView === 'detail') return admShowList();
        return post('adminClose');
    }
    if (e.key !== 'Escape' || $('app').classList.contains('hidden')) return;
    if (!$('modal').classList.contains('hidden')) return closeModal();
    if (view === 'mailbox' && !$('mail-letter').classList.contains('hidden')) return showMailList();
    if (['guests', 'wardrobe', 'mailbox', 'storage'].includes(view)) return showView('main');
    requestClose();
});

/* draggable panel (drag the header, double-click it to reset; position is remembered) */
(function () {
    const panel = $('panel');
    const handle = panel.querySelector('.panel-header');
    const KEY = 'rsg-housing:panel-pos';
    let drag = null;

    function clamp(x, y) {
        const maxX = window.innerWidth - panel.offsetWidth;
        const maxY = window.innerHeight - panel.offsetHeight;
        return { x: Math.max(0, Math.min(x, maxX)), y: Math.max(0, Math.min(y, maxY)) };
    }

    function place(x, y) {
        const p = clamp(x, y);
        panel.classList.add('moved');
        panel.style.left = p.x + 'px';
        panel.style.top = p.y + 'px';
        return p;
    }

    function restore() {
        try {
            const saved = JSON.parse(localStorage.getItem(KEY) || 'null');
            if (saved) place(saved.x, saved.y);
        } catch (e) { /* ignore */ }
    }

    handle.addEventListener('mousedown', (e) => {
        if (e.button !== 0 || e.target.closest('button')) return;
        const rect = panel.getBoundingClientRect();
        drag = { dx: e.clientX - rect.left, dy: e.clientY - rect.top };
        panel.classList.add('dragging');
        e.preventDefault();
    });

    window.addEventListener('mousemove', (e) => {
        if (drag) place(e.clientX - drag.dx, e.clientY - drag.dy);
    });

    window.addEventListener('mouseup', () => {
        if (!drag) return;
        drag = null;
        panel.classList.remove('dragging');
        try {
            localStorage.setItem(KEY, JSON.stringify({ x: parseInt(panel.style.left, 10), y: parseInt(panel.style.top, 10) }));
        } catch (e) { /* ignore */ }
    });

    handle.addEventListener('dblclick', (e) => {
        if (e.target.closest('button')) return;
        panel.classList.remove('moved');
        panel.style.left = panel.style.top = '';
        try { localStorage.removeItem(KEY); } catch (err) { /* ignore */ }
    });

    // keep it on screen when the panel changes size or opens
    new ResizeObserver(() => {
        if (panel.classList.contains('moved')) place(parseInt(panel.style.left, 10), parseInt(panel.style.top, 10));
    }).observe(panel);

    restore();
})();


/* wardrobe (saved outfits from rsg-character) */
let outfitBusy = false;

async function outfitCall(payload) {
    try {
        const res = await fetch(`https://${resource}/outfits`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(payload || {})
        });
        return await res.json();
    } catch (e) {
        return { available: false };
    }
}

function renderOutfits(outfits) {
    if (!outfits.length) {
        $('outfit-rows').innerHTML = `<div class="muted empty">${escapeHtml(S.ui_outfits_empty)}</div>`;
        return;
    }
    $('outfit-rows').innerHTML = outfits.map((o) => `
        <div class="row outfit-row" data-outfit="${Number(o.id)}" data-name="${escapeHtml(o.name)}">
            <div class="badge">${ICONS.outfits}</div>
            <div class="row-body">
                <div class="row-title">${escapeHtml(o.name)}</div>
            </div>
            ${o.default ? `<span class="pill">${escapeHtml(S.ui_outfit_default)}</span>` : ''}
            <button class="wood-btn small" data-wear="${Number(o.id)}">${escapeHtml(S.ui_wear)}</button>
        </div>`).join('');
}

async function outfitAction(payload) {
    if (outfitBusy) return;
    outfitBusy = true;
    $('view-wardrobe').classList.add('busy');
    const data = await outfitCall(payload);
    $('view-wardrobe').classList.remove('busy');
    outfitBusy = false;
    return data;
}

async function openWardrobe() {
    showView('wardrobe');
    $('outfit-rows').innerHTML = '';
    const data = await outfitAction({ action: 'list' });
    if (data && data.available) renderOutfits(data.outfits || []);
    else if (data && !data.skipped) $('outfit-rows').innerHTML = `<div class="muted empty">${escapeHtml(S.ui_outfits_empty)}</div>`;
}

$('outfit-rows').addEventListener('click', async (e) => {
    const row = e.target.closest('[data-outfit]');
    if (!row) return;
    const data = await outfitAction({ action: 'wear', id: Number(row.dataset.outfit) });
    if (!data || data.skipped) return;
    if (data.error) return toast(data.error, 'error');
    if (data.worn) toast(fmt(S.ui_outfit_worn, row.dataset.name), 'success');
});

/* mailbox (rsg-telegram inbox) */
let mail = [];
let mailBusy = false;
let openLetterId = null;

async function mailCall(payload) {
    try {
        const res = await fetch(`https://${resource}/mailbox`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(payload || {})
        });
        return await res.json();
    } catch (e) {
        return { available: false };
    }
}

function mailDate(ts) {
    if (!ts) return '';
    const d = new Date(Number(ts) * 1000);
    return d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short' }) + ' ' + d.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' });
}

function renderMail(data) {
    if (data && data.skipped) return;
    if (!data || !data.available) {
        $('mail-rows').innerHTML = `<div class="muted empty">${escapeHtml(S.ui_mailbox_unavailable)}</div>`;
        return;
    }
    mail = data.mail || [];
    if (status) status.unread = mail.filter((m) => !m.is_read).length;
    if (!mail.length) {
        $('mail-rows').innerHTML = `<div class="muted empty">${escapeHtml(S.ui_mailbox_empty)}</div>`;
        return;
    }
    $('mail-rows').innerHTML = mail.map((m) => `
        <div class="row mail-row${m.is_read ? '' : ' unread'}" data-mail="${Number(m.id)}">
            <div class="badge">${ICONS.mailbox}</div>
            <div class="row-body">
                <div class="row-title">${escapeHtml(m.subject)}</div>
                <div class="row-desc">${escapeHtml(fmt(S.ui_mailbox_from, m.sender_name))}</div>
            </div>
            <span class="mail-date">${escapeHtml(mailDate(m.sent_at))}</span>
        </div>`).join('');
}

async function mailAction(payload) {
    if (mailBusy) return null;
    mailBusy = true;
    $('view-mailbox').classList.add('busy');
    const data = await mailCall(payload);
    renderMail(data);
    $('view-mailbox').classList.remove('busy');
    mailBusy = false;
    return data;
}

function showMailList() {
    openLetterId = null;
    $('mail-letter').classList.add('hidden');
    $('mail-list').classList.remove('hidden');
}

function showLetter(m) {
    openLetterId = m.id;
    $('letter-subject').textContent = m.subject;
    $('letter-meta').textContent = fmt(S.ui_mailbox_from, m.sender_name) + ' \u2022 ' + mailDate(m.sent_at);
    $('letter-body').textContent = m.message;
    $('mail-list').classList.add('hidden');
    $('mail-letter').classList.remove('hidden');
}

function openMailbox() {
    showView('mailbox');
    showMailList();
    $('mail-rows').innerHTML = '';
    mailAction({ action: 'list' });
}

$('mail-rows').addEventListener('click', (e) => {
    const row = e.target.closest('[data-mail]');
    if (!row) return;
    const m = mail.find((x) => Number(x.id) === Number(row.dataset.mail));
    if (!m) return;
    showLetter(m);
    if (!m.is_read) mailAction({ action: 'read', id: m.id });
});

$('btn-letter-back').addEventListener('click', showMailList);

$('btn-letter-delete').addEventListener('click', () => {
    const m = mail.find((x) => Number(x.id) === Number(openLetterId));
    if (!m) return;
    confirmBox(S.ui_confirm_delete_mail, fmt(S.ui_confirm_delete_mail_content, m.subject), async () => {
        await mailAction({ action: 'delete', id: m.id });
        showMailList();
    });
});


/* storage + upgrades */
function tierName(t) { return S['storage_tier_' + t.key] || t.key; }
function tierSpecs(t) {
    return fmt(S.ui_storage_slots, t.slots) + ' \u2022 ' + fmt(S.ui_storage_weight, Math.round(t.weight / 1000).toLocaleString('en-US'));
}

function renderStorage() {
    if (!status || !tiers.length) return;
    const level = Number(status.storageTier || 1);
    const current = tiers[level - 1] || tiers[0];
    const isTenant = status.access === 'tenant';

    $('storage-current').textContent = tierName(current);
    $('storage-specs').textContent = tierSpecs(current);

    $('storage-tiers-label').classList.toggle('hidden', !isTenant);
    if (!isTenant) { $('storage-tiers').innerHTML = ''; return; }

    $('storage-tiers').innerHTML = tiers.map((t, i) => {
        const lvl = i + 1;
        let right;
        if (lvl === level) right = `<span class="pill good">${escapeHtml(S.ui_storage_owned)}</span>`;
        else if (lvl < level) right = `<span class="pill">${escapeHtml(lvl === 1 ? S.ui_storage_included : S.ui_storage_owned)}</span>`;
        else {
            const cost = Math.max(0, t.price - current.price);
            right = `<button class="wood-btn small" data-upgrade="${lvl}">${escapeHtml(fmt(S.ui_storage_upgrade, money(cost)))}</button>`;
        }
        if (lvl === 1 && level !== 1) right = `<span class="pill">${escapeHtml(S.ui_storage_included)}</span>`;
        return `<div class="row static tier-row${lvl === level ? ' current' : ''}${lvl < level ? ' lower' : ''}">
            <div class="badge">${ICONS.storage}</div>
            <div class="row-body">
                <div class="row-title">${escapeHtml(tierName(t))}</div>
                <div class="row-desc">${escapeHtml(tierSpecs(t))}</div>
            </div>
            ${right}
        </div>`;
    }).join('');
}

$('btn-open-storage').addEventListener('click', () => post('action', { action: 'storage' }));

$('storage-tiers').addEventListener('click', (e) => {
    const btn = e.target.closest('[data-upgrade]');
    if (!btn) return;
    const lvl = Number(btn.dataset.upgrade);
    const t = tiers[lvl - 1];
    const current = tiers[Number(status.storageTier || 1) - 1] || tiers[0];
    const cost = Math.max(0, t.price - current.price);
    confirmBox(S.ui_confirm_upgrade, fmt(S.ui_confirm_upgrade_content, tierName(t), money(cost)),
        () => post('action', { action: 'upgradeStorage', level: lvl }));
});


/* ================= admin panel (/houseadmin) ================= */
let AS = {};
let admHouses = [];
let admFilter = 'all';
let admView = 'list';
let admHouse = null;
let admBusy = false;
let admMaxRent = 1000000;

function admStr(key) { return AS[key] || key; }

function admCall(action, houseid, data) {
    return fetch(`https://${resource}/admin`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ action, houseid, data })
    }).then((r) => r.json()).catch(() => ({ ok: false }));
}

function admDays(h) {
    if (h.hoursLeft === null || h.hoursLeft === undefined) return '';
    const days = Math.floor(Math.abs(Number(h.hoursLeft)) / 24);
    return h.overdue ? fmt(admStr('adm_overdue_by'), days) : fmt(admStr('adm_days_left'), days);
}

function admRenderStats() {
    const total = admHouses.length;
    const rented = admHouses.filter((h) => h.rented).length;
    const overdue = admHouses.filter((h) => h.overdue).length;
    const stats = [
        { key: 'all', label: admStr('adm_total'), num: total },
        { key: 'rented', label: admStr('adm_rented'), num: rented, cls: 'good' },
        { key: 'vacant', label: admStr('adm_vacant'), num: total - rented },
        { key: 'overdue', label: admStr('adm_overdue'), num: overdue, cls: overdue ? 'warn' : '' },
    ];
    $('adm-stats').innerHTML = stats.map((st) => `
        <div class="adm-stat ${st.cls || ''}${admFilter === st.key ? ' active' : ''}" data-filter="${st.key}">
            <div class="label">${escapeHtml(st.label)}</div>
            <div class="num">${st.num}</div>
        </div>`).join('');
}

function admRenderList() {
    admRenderStats();
    const q = $('adm-search').value.trim().toLowerCase();
    const list = admHouses.filter((h) => {
        if (admFilter === 'rented' && !h.rented) return false;
        if (admFilter === 'vacant' && h.rented) return false;
        if (admFilter === 'overdue' && !h.overdue) return false;
        if (!q) return true;
        return [h.name, h.houseid, h.customName, h.tenant, h.citizenid, h.region]
            .some((v) => v && String(v).toLowerCase().includes(q));
    });

    if (!list.length) {
        $('adm-list').innerHTML = `<div class="muted empty">${escapeHtml(admStr('adm_no_results'))}</div>`;
        return;
    }

    $('adm-list').innerHTML = list.map((h) => {
        let due = `<span class="pill">${escapeHtml(admStr('adm_vacant'))}</span>`;
        if (h.rented) {
            const cls = h.overdue ? 'bad' : (Number(h.hoursLeft) < 7 * 24 ? 'warn' : 'good');
            due = `<span class="pill ${cls}">${escapeHtml(admDays(h))}</span>`;
            if (h.home) due += ` <span class="pill good">${escapeHtml(admStr('adm_home'))}</span>`;
        }
        return `<div class="adm-row${h.overdue ? ' overdue' : ''}" data-house="${escapeHtml(h.houseid)}">
            <div>
                <div class="cell-main">${escapeHtml(h.customName || h.name)}</div>
                <div class="cell-sub">${escapeHtml(h.houseid)} • ${escapeHtml(h.region || '')}${h.inConfig ? '' : ' • ' + escapeHtml(admStr('adm_not_in_config'))}</div>
            </div>
            <div>
                <div class="cell-main">${escapeHtml(h.tenant || admStr('adm_none'))}</div>
                <div class="cell-sub">${escapeHtml(h.citizenid || '')}</div>
            </div>
            <div class="cell-main">${money(h.rent)}</div>
            <div class="cell-pills">${due}</div>
        </div>`;
    }).join('');
}

function admShowList() {
    admView = 'list';
    admHouse = null;
    $('adm-list-view').classList.remove('hidden');
    $('adm-detail-view').classList.add('hidden');
    $('adm-back').classList.add('hidden');
    $('adm-sub').textContent = admStr('adm_subtitle');
    admRenderList();
}

function admRenderDetail() {
    const h = admHouse;
    if (!h) return;
    $('adm-sub').textContent = (h.customName || h.name) + ' • ' + h.houseid;

    let pills = h.rented
        ? `<span class="pill ${h.overdue ? 'bad' : 'good'}">${escapeHtml(admDays(h))}</span>`
        : `<span class="pill">${escapeHtml(admStr('adm_vacant'))}</span>`;
    if (h.rented) pills += `<span class="pill ${h.home ? 'good' : ''}">${escapeHtml(admStr(h.home ? 'adm_home' : 'adm_away'))}</span>`;
    pills += `<span class="pill">${escapeHtml(admStr('adm_doors'))}: ${escapeHtml(admStr(h.locked ? 'adm_locked' : 'adm_unlocked'))}</span>`;

    $('adm-summary').innerHTML = `
        <div class="status-top">
            <div>
                <div class="label">${escapeHtml(h.houseid)} • ${escapeHtml(h.region || '')}</div>
                <div class="status-line">${escapeHtml(h.name)}</div>
                ${h.customName ? `<div class="cell-sub">${escapeHtml(fmt(admStr('adm_custom_name'), h.customName))}</div>` : ''}
            </div>
            <div class="cell-pills">${pills}</div>
        </div>
        <div class="status-bottom">
            <span class="muted">${escapeHtml(admStr('adm_tenant'))}: <strong>${escapeHtml(h.tenant || admStr('adm_none'))}</strong>${h.citizenid ? ' (' + escapeHtml(h.citizenid) + ')' : ''}</span>
            <span class="muted">${h.rented ? escapeHtml(admStr('adm_due')) + ': <strong>' + escapeHtml(h.due || '') + '</strong>' : ''}</span>
        </div>`;

    $('adm-rent').value = h.rent;
    $('adm-rent').max = admMaxRent;
    $('adm-tenancy').classList.toggle('hidden', !h.rented);
    $('adm-due-date').value = h.due ? h.due.slice(0, 10) : '';
    $('adm-due-date').min = new Date().toISOString().slice(0, 10);
    $('adm-reset-name').disabled = !h.customName;
    $('adm-lock').disabled = h.locked;
    $('adm-unlock').disabled = !h.locked;
    $('adm-teleport').disabled = !h.inConfig;
    $('adm-storage').disabled = !h.inConfig;

    $('adm-tiers').innerHTML = tiers.map((t, i) => {
        const lvl = i + 1;
        return `<button class="wood-btn adm-tier${lvl === h.storageTier ? ' current' : ''}" data-tier="${lvl}">
            ${escapeHtml(AS['storage_tier_' + t.key] || t.key)}
            <span class="tier-specs">${escapeHtml(fmt(admStr('ui_storage_slots'), t.slots) + ' \u2022 ' + fmt(admStr('ui_storage_weight'), Math.round(t.weight / 1000).toLocaleString('en-US')))}</span>
        </button>`;
    }).join('');

    const guests = h.guestList || [];
    $('adm-guests-wrap').classList.toggle('hidden', !h.rented);
    $('adm-guests').innerHTML = guests.length ? guests.map((g) => `
        <div class="row static">
            <div class="badge">${ICONS.person}</div>
            <div class="row-body">
                <div class="row-title">${escapeHtml(g.name || g.citizenid)}</div>
                <div class="row-desc">${escapeHtml(g.citizenid)}</div>
            </div>
            <button class="wood-btn muted small" data-adm-remove="${escapeHtml(g.citizenid)}">${escapeHtml(admStr('ui_remove'))}</button>
        </div>`).join('') : `<div class="muted empty">${escapeHtml(admStr('adm_no_guests'))}</div>`;
}

async function admOpenHouse(houseid) {
    const res = await admCall('house', houseid);
    if (!res.ok || !res.house) return;
    admHouse = res.house;
    admView = 'detail';
    $('adm-list-view').classList.add('hidden');
    $('adm-detail-view').classList.remove('hidden');
    $('adm-back').classList.remove('hidden');
    admRenderDetail();
}

async function admRefreshList(silent) {
    const res = await admCall('list');
    if (!res.ok) return;
    admHouses = res.houses || [];
    if (admView === 'list') admRenderList();
    if (!silent) toast(admStr('adm_refresh'), 'inform', admStr('adm_title'));
}

async function admAction(action, data) {
    if (admBusy || !admHouse) return;
    admBusy = true;
    $('adm-detail-view').classList.add('busy');
    const res = await admCall(action, admHouse.houseid, data);
    $('adm-detail-view').classList.remove('busy');
    admBusy = false;
    if (res.msg) toast(res.msg, res.type || (res.ok ? 'success' : 'error'), admStr('adm_title'));
    if (res.house) {
        admHouse = res.house;
        const i = admHouses.findIndex((x) => x.houseid === res.house.houseid);
        if (i >= 0) admHouses[i] = res.house;
        admRenderDetail();
    }
}

function adminOpen(data) {
    AS = data.strings || AS;
    S = Object.assign({}, AS, S); // the shared confirm modal reads S
    tiers = data.tiers || tiers;
    admMaxRent = data.maxRent || admMaxRent;
    admHouses = data.houses || [];
    admFilter = 'all';
    document.querySelectorAll('#admin [data-str], #modal [data-str]').forEach((el) => { el.textContent = admStr(el.dataset.str); });
    document.querySelectorAll('#admin [data-title]').forEach((el) => { el.title = admStr(el.dataset.title); });
    $('adm-search').placeholder = admStr('adm_search');
    $('adm-search').value = '';
    $('admin').classList.remove('hidden');
    admShowList();
}

function adminClose() {
    $('admin').classList.add('hidden');
    closeModal();
    admHouse = null;
}

$('adm-close').addEventListener('click', () => post('adminClose'));
$('adm-back').addEventListener('click', () => { admShowList(); admRefreshList(true); });
$('adm-refresh').addEventListener('click', async () => {
    if (admView === 'detail' && admHouse) await admOpenHouse(admHouse.houseid);
    await admRefreshList(admView === 'detail');
});
$('adm-search').addEventListener('input', admRenderList);
$('adm-stats').addEventListener('click', (e) => {
    const st = e.target.closest('[data-filter]');
    if (!st) return;
    admFilter = st.dataset.filter;
    admRenderList();
});
$('adm-list').addEventListener('click', (e) => {
    const row = e.target.closest('[data-house]');
    if (row) admOpenHouse(row.dataset.house);
});

$('adm-rent-save').addEventListener('click', () => {
    const rent = Math.floor(Number($('adm-rent').value));
    if (!Number.isFinite(rent) || rent < 0 || rent > admMaxRent) return toast(admStr('adm_rent'), 'error', admStr('adm_title'));
    admAction('setRent', { rent });
});
$('adm-due-minus').addEventListener('click', () => admAction('shiftDue', { months: -1 }));
$('adm-due-plus').addEventListener('click', () => admAction('shiftDue', { months: 1 }));
$('adm-due-set').addEventListener('click', () => {
    const date = $('adm-due-date').value;
    if (date) admAction('setDue', { date });
});
$('adm-tiers').addEventListener('click', (e) => {
    const btn = e.target.closest('[data-tier]');
    if (btn && Number(btn.dataset.tier) !== admHouse.storageTier) admAction('setStorage', { level: Number(btn.dataset.tier) });
});
$('adm-lock').addEventListener('click', () => admAction('doors', { locked: true }));
$('adm-unlock').addEventListener('click', () => admAction('doors', { locked: false }));
$('adm-reset-name').addEventListener('click', () => admAction('resetName'));
$('adm-teleport').addEventListener('click', () => admAction('teleport'));
$('adm-storage').addEventListener('click', () => admAction('storage'));
$('adm-guests').addEventListener('click', (e) => {
    const btn = e.target.closest('[data-adm-remove]');
    if (btn) admAction('removeGuest', { citizenid: btn.dataset.admRemove });
});

function admConfirmEvict(purge) {
    if (!admHouse || !admHouse.rented) return;
    const title = admStr(purge ? 'adm_evict_purge' : 'adm_evict_keep');
    $('modal-cancel').textContent = admStr('ui_cancel');
    $('modal-confirm').textContent = admStr('ui_confirm');
    confirmBox(title, fmt(admStr('adm_confirm_evict_content'), admHouse.tenant, admHouse.customName || admHouse.name),
        () => admAction('evict', { purge }));
    $('modal-confirm').textContent = admStr('ui_confirm');
}
$('adm-evict-keep').addEventListener('click', () => admConfirmEvict(false));
$('adm-evict-purge').addEventListener('click', () => admConfirmEvict(true));
