'use strict';

const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'rsg-society';

const S = { strings: {}, view: null, tab: 'overview', mode: 'menu' };

/* ---------------------------------------------------------------- helpers */
function t(key, ...args) {
    let s = S.strings[key] !== undefined ? S.strings[key] : key;
    let i = 0;
    return String(s).replace(/%[sd]/g, () => (i < args.length ? args[i++] : ''));
}

function h(tag, props, ...kids) {
    const el = document.createElement(tag);
    if (props) {
        for (const k of Object.keys(props)) {
            const v = props[k];
            if (v === undefined || v === null || v === false) continue;
            if (k === 'class') el.className = v;
            else if (k === 'text') el.textContent = v;
            else if (k.startsWith('on')) el.addEventListener(k.slice(2).toLowerCase(), v);
            else if (k === 'value') el.value = v;
            else el.setAttribute(k, v === true ? '' : v);
        }
    }
    for (const kid of kids.flat()) {
        if (kid === undefined || kid === null || kid === false) continue;
        el.appendChild(typeof kid === 'string' || typeof kid === 'number' ? document.createTextNode(String(kid)) : kid);
    }
    return el;
}

const $ = (id) => document.getElementById(id);
const money = (n) => '$' + Number(n || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const has = (p) => !!(S.view && S.view.perms && S.view.perms.includes(p));

async function api(name, data) {
    try {
        const res = await fetch(`https://${RES}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        });
        return await res.json();
    } catch (e) {
        return { ok: false, msg: t('ui_no_answer') };
    }
}

function applyI18n() {
    document.querySelectorAll('[data-i18n-title]').forEach((el) => { el.title = t(el.dataset.i18nTitle); });
}

/* ---------------------------------------------------------------- toasts */
function toast(msg, type) {
    if (!msg) return;
    const el = h('div', { class: 'toast ' + (type || '') },
        h('div', { class: 't-label', text: t('ui_toast_label') }),
        h('div', { class: 't-msg', text: msg }));
    $('toasts').appendChild(el);
    setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 260); }, 3800);
}

/* ---------------------------------------------------------------- dropdown (never a native select) */
function closeDropdowns(except) {
    document.querySelectorAll('.dd.open').forEach((d) => { if (d !== except) { d.classList.remove('open'); const m = d.querySelector('.dd-menu'); if (m) m.remove(); } });
}
document.addEventListener('mousedown', (e) => { if (!e.target.closest('.dd')) closeDropdowns(); });

function makeDd(options, value, onChange, small) {
    const dd = h('div', { class: 'dd' + (small ? ' small' : '') });
    dd.dataset.value = value === undefined || value === null ? '' : String(value);
    const label = h('div', { class: 'dd-value' });
    dd.appendChild(label);
    dd.appendChild(h('span', { class: 'arrow' }));

    function refresh() {
        const cur = options.find((o) => String(o.value) === dd.dataset.value);
        label.textContent = cur ? cur.label : (options.length ? t('ui_choose') : t('ui_none_available'));
    }
    refresh();

    dd.addEventListener('mousedown', (e) => {
        if (e.target.closest('.dd-menu')) return;
        e.preventDefault();
        if (dd.classList.contains('open')) { closeDropdowns(); return; }
        closeDropdowns(dd);
        dd.classList.add('open');
        const menu = h('div', { class: 'dd-menu' });
        if (!options.length) menu.appendChild(h('div', { class: 'dd-opt none', text: t('ui_none_available') }));
        options.forEach((o) => {
            const opt = h('div', { class: 'dd-opt' + (String(o.value) === dd.dataset.value ? ' selected' : ''), text: o.label });
            opt.addEventListener('mousedown', (ev) => {
                ev.preventDefault(); ev.stopPropagation();
                const changed = dd.dataset.value !== String(o.value);
                dd.dataset.value = String(o.value);
                refresh();
                closeDropdowns();
                if (changed && onChange) onChange(o.value);
            });
            menu.appendChild(opt);
        });
        dd.appendChild(menu);
    });
    return dd;
}
const ddValue = (dd) => dd.dataset.value;

/* ---------------------------------------------------------------- modal */
function openModal(title, body, actions) {
    $('modal-title').textContent = title;
    const b = $('modal-body'); b.innerHTML = '';
    if (body) b.appendChild(body);
    const a = $('modal-actions'); a.innerHTML = '';
    (actions || []).forEach((act) => {
        a.appendChild(h('button', { class: 'wood-btn ' + (act.cls || ''), text: act.label, onClick: () => { if (act.onClick) act.onClick(); else closeModal(); } }));
    });
    $('modal-layer').classList.remove('hidden');
    const first = b.querySelector('input'); if (first) setTimeout(() => first.focus(), 30);
}
function closeModal() { closeDropdowns(); $('modal-layer').classList.add('hidden'); }

function confirmModal(title, text, onYes, danger) {
    openModal(title, h('p', { text }), [
        { label: t('ui_confirm'), cls: danger ? 'danger' : '', onClick: () => { closeModal(); onYes(); } },
        { label: t('ui_cancel'), cls: 'muted-btn' },
    ]);
}

/* ---------------------------------------------------------------- clipboard */
function copyText(text) {
    const ta = h('textarea', { style: 'position:fixed;left:-9999px;top:0' });
    ta.value = text;
    document.body.appendChild(ta);
    ta.select();
    let ok = false;
    try { ok = document.execCommand('copy'); } catch (e) { ok = false; }
    ta.remove();
    return ok;
}

/* ---------------------------------------------------------------- actions */
async function act(action, data, quiet) {
    const res = await api('act', { society: S.view.name, action, data: data || {} });
    if (res.msg && !quiet) toast(res.msg, res.ok ? 'success' : 'error');
    if (res.view) { S.view = res.view; renderHeader(); renderTabs(); }
    return res;
}

async function fetchTab(tab, arg) {
    return api('tab', { society: S.view.name, tab, arg });
}

/* ---------------------------------------------------------------- shell */
function renderHeader() {
    const v = S.view;
    $('title').textContent = v.label + (v.tag ? '  [' + v.tag + ']' : '');
    $('subtitle').textContent = (v.type === 'gang' ? t('ui_type_gang') : t('ui_type_job')) + ' · ' + (v.me ? v.me.grade : '');
}

function tabList() {
    const list = ['overview'];
    if (has('members')) list.push('members');
    if (has('ranks')) list.push('ranks');
    if (has('finance')) list.push('finance');
    if (has('fines') || has('finevoid')) list.push('fines');
    if (has('audit')) list.push('audit');
    if (has('audit')) list.push('stash');
    if (S.view.type === 'gang') list.push('settings');
    return list;
}

function renderTabs() {
    const list = tabList();
    if (!list.includes(S.tab)) S.tab = 'overview';
    const bar = $('tabs'); bar.innerHTML = '';
    list.forEach((id) => {
        bar.appendChild(h('div', { class: 'tab' + (id === S.tab ? ' active' : ''), text: t('ui_tab_' + id), onClick: () => { S.tab = id; renderTabs(); loadTab(); } }));
    });
}

async function loadTab() {
    const c = $('content');
    closeDropdowns();
    if (S.tab === 'overview') return renderOverview();
    c.innerHTML = '';
    c.appendChild(h('div', { class: 'empty', text: t('ui_loading') }));
    const tab = S.tab;
    const res = await fetchTab(tab, tab === 'finance' ? { kind: S.ledgerKind || '' } : undefined);
    if (S.tab !== tab) return;
    if (!res.ok) { c.innerHTML = ''; c.appendChild(h('div', { class: 'empty', text: res.msg || t('ui_no_answer') })); return; }
    const fn = { members: renderMembers, ranks: renderRanks, finance: renderFinance, fines: renderFines, audit: renderAudit, stash: renderStash, settings: renderSettings }[tab];
    c.innerHTML = '';
    fn(res, c);
}

function refreshTab() { return loadTab(); }

/* ---------------------------------------------------------------- overview */
function amountModal(title, action, extra, cap) {
    const input = h('input', { class: 'input', type: 'number', min: '0.01', max: S.view.maxTransaction || undefined, step: '0.01', placeholder: t('ui_amount') });
    const submit = async () => {
        const res = await act(action, Object.assign({ amount: parseFloat(input.value) }, extra || {}));
        if (res.ok) { closeModal(); refreshTab(); }
    };
    input.addEventListener('keydown', (e) => { if (e.key === 'Enter') submit(); });
    const field = h('div', { class: 'field' }, h('label', { text: t('ui_amount') }), input);
    if (cap > 0) {
        field.appendChild(h('button', { class: 'wood-btn small', style: 'margin-top:8px', text: t('ui_max') + ' ' + money(cap), onClick: () => { input.value = cap.toFixed(2); input.focus(); } }));
    }
    openModal(title, field, [
        { label: t('ui_confirm'), onClick: submit },
        { label: t('ui_cancel'), cls: 'muted-btn' },
    ]);
}

function motdModal() {
    const input = h('input', { class: 'input', maxlength: '200', value: S.view.motd || '', placeholder: t('ui_motd') });
    const submit = async () => {
        const res = await act('motd', { text: input.value });
        if (res.ok) { closeModal(); renderOverview(); }
    };
    input.addEventListener('keydown', (e) => { if (e.key === 'Enter') submit(); });
    openModal(t('ui_motd_edit'), h('div', { class: 'field' }, h('label', { text: t('ui_motd') }), input), [
        { label: t('ui_save'), onClick: submit },
        { label: t('ui_cancel'), cls: 'muted-btn' },
    ]);
}

function renderOverview() {
    const v = S.view, c = $('content');
    c.innerHTML = '';
    const stats = h('div', { class: 'stats' });
    if (v.balance !== undefined && v.balance !== null) {
        stats.appendChild(h('div', { class: 'stat' }, h('div', { class: 'label', text: t('ui_balance') }), h('div', { class: 'value', text: money(v.balance) })));
    }
    stats.appendChild(h('div', { class: 'stat' }, h('div', { class: 'label', text: t('ui_your_rank') }), h('div', { class: 'value', text: v.me.grade })));
    if (v.type === 'gang') {
        const n = v.members + (v.maxMembers ? ' / ' + v.maxMembers : '');
        stats.appendChild(h('div', { class: 'stat' }, h('div', { class: 'label', text: t('ui_tab_members') }), h('div', { class: 'value', text: n })));
    }
    stats.appendChild(h('div', { class: 'stat' }, h('div', { class: 'label', text: t('ui_payroll') }),
        h('div', { class: 'value ' + (v.payroll ? 'ok' : 'bad'), text: v.payroll ? t('ui_on') : t('ui_off') })));
    c.appendChild(stats);
    if (v.motd) c.appendChild(h('div', { class: 'notice' }, h('b', { text: t('ui_motd') + ': ' }), v.motd));

    const bar = h('div', { class: 'toolbar' });
    const left = h('div', { class: 'actions', style: 'display:flex;gap:8px;flex-wrap:wrap' });
    if (has('deposit')) left.appendChild(h('button', { class: 'wood-btn', text: t('ui_deposit'), onClick: () => amountModal(t('ui_deposit'), 'deposit') }));
    if (has('withdraw')) left.appendChild(h('button', { class: 'wood-btn', text: t('ui_withdraw'), onClick: () => amountModal(t('ui_withdraw'), 'withdraw', null, Math.min(v.balance || 0, v.maxTransaction || Infinity)) }));
    if (has('storage') && v.remoteStorage) left.appendChild(h('button', { class: 'wood-btn', text: t('ui_storage'), onClick: () => act('storage') }));
    if (has('announce')) left.appendChild(h('button', { class: 'wood-btn', text: t('ui_motd_edit'), onClick: motdModal }));
    bar.appendChild(left);
    c.appendChild(bar);
    c.appendChild(h('div', { class: 'italic', text: t('ui_overview_hint') }));
}

/* ---------------------------------------------------------------- members */
function hireModal(grades) {
    const body = h('div');
    const rankDd = makeDd(grades.map((g) => ({ value: g.level, label: g.name })), grades.length ? grades[0].level : '', null, false);
    const slot = h('div', { class: 'field' }, h('label', { text: t('ui_player') }), h('div', { class: 'muted', text: t('ui_loading') }));
    body.appendChild(slot);
    body.appendChild(h('div', { class: 'field' }, h('label', { text: t('ui_rank') }), rankDd));
    let playerDd = null;
    openModal(S.view.type === 'gang' ? t('ui_invite') : t('ui_hire'), body, [
        { label: t('ui_confirm'), onClick: async () => {
            if (!playerDd || ddValue(playerDd) === '') return;
            const res = await act('invite', { target: parseInt(ddValue(playerDd), 10), level: parseInt(ddValue(rankDd), 10) });
            if (res.ok) { closeModal(); refreshTab(); }
        } },
        { label: t('ui_cancel'), cls: 'muted-btn' },
    ]);
    fetchTab('nearby', { purpose: 'hire' }).then((res) => {
        slot.innerHTML = '';
        slot.appendChild(h('label', { text: t('ui_player') }));
        playerDd = makeDd(((res && res.players) || []).map((p) => ({ value: p.id, label: p.name })), '', null, false);
        slot.appendChild(playerDd);
        if (!res.players || !res.players.length) slot.appendChild(h('div', { class: 'italic', text: t('ui_nobody_near') }));
    });
}

function memberRow(m, data) {
    const actions = h('div', { class: 'actions' });
    if (m.self) actions.appendChild(h('span', { class: 'badge', text: t('ui_you') }));
    if (m.canManage && data.canPromote) {
        actions.appendChild(makeDd(data.assignable.map((g) => ({ value: g.level, label: g.name })), m.level, async (lvl) => {
            const res = await act('setrank', { cid: m.cid, level: parseInt(lvl, 10) });
            refreshTab();
            return res;
        }, true));
    } else {
        actions.appendChild(h('span', { class: 'badge ' + (m.boss ? 'boss' : ''), text: m.grade }));
    }
    if (data.canBonus && !m.self && m.online) {
        actions.appendChild(h('button', { class: 'wood-btn small', text: t('ui_bonus'), onClick: () =>
            amountModal(t('ui_bonus') + ' - ' + m.name, 'bonus', { cid: m.cid }) }));
    }
    if (m.canManage && data.canTransfer) {
        actions.appendChild(h('button', { class: 'wood-btn small', text: t('ui_transfer'), onClick: () =>
            confirmModal(t('ui_transfer'), t('ui_transfer_confirm', m.name), async () => { await act('transfer', { cid: m.cid }); refreshTab(); }) }));
    }
    if (m.canManage && data.canFire) {
        actions.appendChild(h('button', { class: 'wood-btn small danger', text: t('ui_fire'), onClick: () =>
            confirmModal(t('ui_fire'), t('ui_fire_confirm', m.name), async () => { await act('fire', { cid: m.cid }); refreshTab(); }, true) }));
    }
    return h('div', { class: 'row' },
        h('div', { class: 'dot' + (m.online ? ' on' : ''), title: m.online ? t('ui_online') : t('ui_offline') }),
        h('div', { class: 'main' }, h('div', { class: 'name', text: m.name }), h('div', { class: 'sub', text: m.grade + ' · ' + m.cid })),
        actions);
}

function renderMembers(data, c) {
    const bar = h('div', { class: 'toolbar' }, h('div', { class: 'grow muted', text: t('ui_member_count', data.members.length) }));
    if (data.canHire) bar.appendChild(h('button', { class: 'wood-btn', text: S.view.type === 'gang' ? t('ui_invite') : t('ui_hire'), onClick: () => hireModal(data.assignable) }));
    c.appendChild(bar);
    if (!data.members.length) c.appendChild(h('div', { class: 'empty', text: t('ui_no_members') }));

    let query = '', onlyOnline = false;
    const list = h('div');
    const draw = () => {
        list.innerHTML = '';
        const q = query.trim().toLowerCase();
        data.members
            .filter((m) => (!onlyOnline || m.online) && (!q || (m.name + ' ' + m.cid + ' ' + m.grade).toLowerCase().includes(q)))
            .forEach((m) => list.appendChild(memberRow(m, data)));
    };
    if (data.members.length > 6) {
        const search = h('input', { class: 'input', placeholder: t('ui_search'), style: 'flex:1' });
        search.addEventListener('input', () => { query = search.value; draw(); });
        const chip = h('div', { class: 'chip', text: t('ui_only_online') });
        chip.addEventListener('click', () => { onlyOnline = !onlyOnline; chip.classList.toggle('on', onlyOnline); draw(); });
        c.appendChild(h('div', { class: 'toolbar' }, search, chip));
    }
    c.appendChild(list);
    draw();
}

/* ---------------------------------------------------------------- ranks */
function rankAddModal() {
    const input = h('input', { class: 'input', maxlength: '24', placeholder: t('ui_rank') });
    const submit = async () => {
        const res = await act('rank_add', { name: input.value });
        if (res.ok) { closeModal(); refreshTab(); }
    };
    input.addEventListener('keydown', (e) => { if (e.key === 'Enter') submit(); });
    openModal(t('ui_rank_add'), h('div', { class: 'field' }, h('label', { text: t('ui_rank') }), input), [
        { label: t('ui_confirm'), onClick: submit },
        { label: t('ui_cancel'), cls: 'muted-btn' },
    ]);
}

function renderRanks(data, c) {
    c.appendChild(h('div', { class: 'notice', text: data.gang ? t('ui_ranks_hint_gang') : t('ui_ranks_hint_job') }));
    if (data.canEditRanks && data.count < data.maxRanks) {
        c.appendChild(h('div', { class: 'toolbar' }, h('div', { class: 'grow' }),
            h('button', { class: 'wood-btn', text: t('ui_rank_add'), onClick: rankAddModal })));
    }
    data.grades.slice().sort((a, b) => b.level - a.level).forEach((g) => {
        const on = new Set(g.perms);
        const card = h('div', { class: 'row', style: 'display:block' });
        const head = h('div', { style: 'display:flex;align-items:center;gap:10px;flex-wrap:wrap' });
        let nameInput = null, payInput = null;
        if (data.gang && g.editable) {
            nameInput = h('input', { class: 'input', style: 'width:200px', value: g.name, maxlength: '24' });
            payInput = h('input', { class: 'input', style: 'width:110px', type: 'number', min: '0', step: '0.01', value: String(g.pay) });
            head.appendChild(nameInput);
            head.appendChild(h('span', { class: 'muted', text: t('ui_pay') }));
            head.appendChild(payInput);
        } else {
            head.appendChild(h('div', { class: 'name', text: g.name }));
            head.appendChild(h('span', { class: 'muted', text: t('ui_pay') + ' ' + money(g.pay) }));
        }
        if (g.boss) head.appendChild(h('span', { class: 'badge boss', text: t('ui_boss') }));
        if (g.deletable) {
            head.appendChild(h('button', { class: 'wood-btn small danger', style: 'margin-left:auto', text: t('ui_rank_delete'), onClick: () =>
                confirmModal(t('ui_rank_delete'), t('ui_rank_delete_confirm', g.name), async () => { await act('rank_delete', { level: g.level }); refreshTab(); }, true) }));
        }
        card.appendChild(head);

        if (g.boss) {
            card.appendChild(h('div', { class: 'italic', style: 'margin-top:8px', text: t('ui_all_perms') }));
        } else {
            const chips = h('div', { class: 'chips' });
            data.allPerms.forEach((p) => {
                const canToggle = g.editable && data.grantable.includes(p);
                const chip = h('div', { class: 'chip' + (on.has(p) ? ' on' : '') + (canToggle ? '' : ' locked'), text: t('ui_perm_' + p) });
                if (canToggle) chip.addEventListener('click', () => { if (on.has(p)) { on.delete(p); chip.classList.remove('on'); } else { on.add(p); chip.classList.add('on'); } });
                chips.appendChild(chip);
            });
            card.appendChild(chips);
            if (g.editable) {
                card.appendChild(h('div', { style: 'margin-top:10px;text-align:right' },
                    h('button', { class: 'wood-btn small', text: t('ui_save'), onClick: async () => {
                        // one request: the server checks the name, the wage and the permissions together
                        const body = { level: g.level, perms: Array.from(on) };
                        if (nameInput) body.meta = { name: nameInput.value, pay: parseFloat(payInput.value) || 0 };
                        const res = await act('perms', body);
                        if (res.ok) refreshTab();
                    } })));
            }
        }
        c.appendChild(card);
    });
}

/* ---------------------------------------------------------------- finance */
const KIND_CLASS = { deposit: 'good', withdraw: 'warn', payroll: '', fine: 'good', refund: '', api: '', admin: 'warn', migration: '', bonus: 'warn', transfer: '' };

function ledgerRow(r) {
    return h('div', { class: 'row' },
        h('div', { class: 'main' },
            h('div', { class: 'name' }, h('span', { class: 'badge ' + (KIND_CLASS[r.kind] || ''), text: t('ui_kind_' + r.kind) }), ' ', r.actor),
            h('div', { class: 'sub', text: (r.note ? r.note + ' · ' : '') + r.date })),
        h('div', { style: 'text-align:right' },
            h('div', { class: r.amount >= 0 ? 'amount-pos' : 'amount-neg', text: (r.amount >= 0 ? '+' : '') + money(r.amount) }),
            h('div', { class: 'sub', text: money(r.balance) })));
}

/** A page list with a "load more" button. Rows carry an id; the next page is asked for with { before: lastId }. */
function pager(c, tab, first, rowsKey, render) {
    const list = h('div'); c.appendChild(list);
    let last = 0;
    const append = (rows) => rows.forEach((r) => { list.appendChild(render(r)); last = r.id; });
    append(first[rowsKey]);
    const addMore = (more) => {
        if (!more) return;
        const btn = h('button', { class: 'wood-btn muted-btn', style: 'display:block;margin:10px auto', text: t('ui_load_more'), onClick: async () => {
            btn.disabled = true;
            const res = await fetchTab(tab, { before: last, kind: tab === 'finance' ? (S.ledgerKind || '') : undefined });
            if (res.ok) { btn.remove(); append(res[rowsKey]); addMore(res.more); }
            else { btn.disabled = false; toast(res.msg, 'error'); }
        } });
        c.appendChild(btn);
    };
    addMore(first.more);
}

const LEDGER_KINDS = ['deposit', 'withdraw', 'payroll', 'fine', 'bonus', 'transfer', 'refund', 'api', 'admin', 'migration'];

function transferModal(data) {
    const body = h('div');
    const to = makeDd(data.transferTargets.map((x) => ({ value: x.name, label: x.label })), '', null, false);
    const amount = h('input', { class: 'input', type: 'number', step: '0.01', min: '0.01', max: data.transferMax || undefined, placeholder: t('ui_amount') });
    body.appendChild(h('div', { class: 'field' }, h('label', { text: t('ui_to_society') }), to));
    body.appendChild(h('div', { class: 'field' }, h('label', { text: t('ui_amount') }), amount));
    openModal(t('ui_transfer_funds'), body, [
        { label: t('ui_confirm'), onClick: async () => {
            if (ddValue(to) === '') return;
            const res = await act('transfer_funds', { to: ddValue(to), amount: parseFloat(amount.value) });
            if (res.ok) { closeModal(); refreshTab(); }
        } },
        { label: t('ui_cancel'), cls: 'muted-btn' },
    ]);
}

function ledgerCsv(rows) {
    const esc = (v) => '"' + String(v === undefined || v === null ? '' : v).replace(/"/g, '""') + '"';
    const lines = [['date', 'type', 'actor', 'note', 'amount', 'balance'].map(esc).join(',')];
    rows.forEach((r) => lines.push([r.date, r.kind, r.actor, r.note, r.amount.toFixed(2), r.balance.toFixed(2)].map(esc).join(',')));
    return lines.join('\n');
}

function renderFinance(data, c) {
    if (!data.payrollEnabled) c.appendChild(h('div', { class: 'notice', text: t('ui_payroll_disabled') }));
    const stats = h('div', { class: 'stats' },
        h('div', { class: 'stat' }, h('div', { class: 'label', text: t('ui_balance') }), h('div', { class: 'value', text: money(data.balance) })));
    c.appendChild(stats);

    const bar = h('div', { class: 'toolbar' });
    const left = h('div', { style: 'display:flex;gap:8px;flex-wrap:wrap' });
    if (data.canDeposit) left.appendChild(h('button', { class: 'wood-btn', text: t('ui_deposit'), onClick: () => amountModal(t('ui_deposit'), 'deposit') }));
    if (data.canWithdraw) left.appendChild(h('button', { class: 'wood-btn', text: t('ui_withdraw'), onClick: () => amountModal(t('ui_withdraw'), 'withdraw', null, Math.min(data.balance, data.max)) }));
    if (data.transferTargets && data.transferTargets.length) left.appendChild(h('button', { class: 'wood-btn', text: t('ui_transfer_funds'), onClick: () => transferModal(data) }));
    bar.appendChild(left);
    const sw = h('div', { class: 'switch' + (data.payroll ? ' on' : '') + (data.canPayroll ? '' : ' locked') },
        h('div', { class: 'track' }), h('span', { text: t('ui_payroll') }));
    if (data.canPayroll) sw.addEventListener('click', async () => {
        const res = await act('payroll', { enabled: !data.payroll });
        if (res.ok) refreshTab();
    });
    bar.appendChild(sw);
    c.appendChild(bar);

    c.appendChild(h('div', { class: 'italic', style: 'margin-bottom:6px', text: t('ui_payroll_hint') }));
    const paid = data.wages.filter((w) => w.pay > 0);
    if (paid.length) {
        c.appendChild(h('div', { class: 'section-title', text: t('ui_wages') }));
        paid.forEach((w) => c.appendChild(h('div', { class: 'row' }, h('div', { class: 'main' }, h('div', { class: 'name', text: w.name })), h('div', { text: money(w.pay) }))));
    }

    c.appendChild(h('div', { class: 'section-title', text: t('ui_ledger') }));
    const loaded = [];
    const filter = makeDd([{ value: '', label: t('ui_filter_all') }].concat(LEDGER_KINDS.map((k) => ({ value: k, label: t('ui_kind_' + k) }))),
        S.ledgerKind || '', (v) => { S.ledgerKind = v; refreshTab(); }, true);
    c.appendChild(h('div', { class: 'toolbar' }, filter, h('div', { class: 'grow' }),
        h('button', { class: 'wood-btn small muted-btn', text: t('ui_copy_csv'), onClick: () => {
            const ok = copyText(ledgerCsv(loaded));
            toast(ok ? t('ui_copied') : t('ui_no_answer'), ok ? 'success' : 'error');
        } })));
    if (!data.ledger.length) c.appendChild(h('div', { class: 'empty', text: t('ui_ledger_empty') }));
    pager(c, 'finance', data, 'ledger', (r) => { loaded.push(r); return ledgerRow(r); });
}

/* ---------------------------------------------------------------- fines */
function fineModal() {
    const body = h('div');
    const slot = h('div', { class: 'field' }, h('label', { text: t('ui_player') }), h('div', { class: 'muted', text: t('ui_loading') }));
    const amount = h('input', { class: 'input', type: 'number', step: '0.01', min: '0.01', placeholder: t('ui_amount') });
    const reason = h('input', { class: 'input', maxlength: '200', placeholder: t('ui_reason') });
    body.appendChild(slot);
    body.appendChild(h('div', { class: 'field' }, h('label', { text: t('ui_amount') }), amount));
    body.appendChild(h('div', { class: 'field' }, h('label', { text: t('ui_reason') }), reason));
    let playerDd = null;
    openModal(t('ui_issue_fine'), body, [
        { label: t('ui_confirm'), onClick: async () => {
            if (!playerDd || ddValue(playerDd) === '') return;
            const res = await act('fine', { target: parseInt(ddValue(playerDd), 10), amount: parseFloat(amount.value), reason: reason.value });
            if (res.ok) { closeModal(); refreshTab(); }
        } },
        { label: t('ui_cancel'), cls: 'muted-btn' },
    ]);
    fetchTab('nearby', { purpose: 'fine' }).then((res) => {
        slot.innerHTML = '';
        slot.appendChild(h('label', { text: t('ui_player') }));
        playerDd = makeDd(((res && res.players) || []).map((p) => ({ value: p.id, label: p.name })), '', null, false);
        slot.appendChild(playerDd);
        if (!res.players || !res.players.length) slot.appendChild(h('div', { class: 'italic', text: t('ui_nobody_near') }));
    });
}

function fineRow(f, canVoid) {
    const actions = h('div', { class: 'actions' });
    actions.appendChild(h('span', { class: 'badge ' + (f.status === 'paid' ? 'good' : f.status === 'void' ? '' : 'warn'), text: t('ui_fine_' + f.status) }));
    if (canVoid && f.status === 'unpaid') {
        actions.appendChild(h('button', { class: 'wood-btn small danger', text: t('ui_void'), onClick: () =>
            confirmModal(t('ui_void'), t('ui_void_confirm', f.target), async () => { await act('voidfine', { id: f.id }); refreshTab(); }, true) }));
    }
    return h('div', { class: 'row' },
        h('div', { class: 'main' },
            h('div', { class: 'name', text: f.target + ' · ' + money(f.amount) + (f.paid > 0 && f.status === 'unpaid' ? ' (' + money(f.paid) + ' ' + t('ui_paid') + ')' : '') }),
            h('div', { class: 'sub', text: (f.reason ? f.reason + ' · ' : '') + f.issuer + ' · ' + f.date })),
        actions);
}

function renderFines(data, c) {
    const bar = h('div', { class: 'toolbar' }, h('div', { class: 'grow muted', text: t('ui_fines_hint', money(data.min), money(data.max)) }));
    if (data.canIssue && data.enabled) bar.appendChild(h('button', { class: 'wood-btn', text: t('ui_issue_fine'), onClick: fineModal }));
    c.appendChild(bar);
    if (!data.fines.length) c.appendChild(h('div', { class: 'empty', text: t('ui_fines_empty') }));
    pager(c, 'fines', data, 'fines', (f) => fineRow(f, data.canVoid));
}

/* ---------------------------------------------------------------- audit */
function auditRow(r) {
    const who = r.actor || t('ui_system');
    return h('div', { class: 'row' },
        h('div', { class: 'main' },
            h('div', { class: 'name' }, h('span', { class: 'badge', text: S.strings['ui_act_' + r.action] || r.action }), ' ', who + (r.target ? '  →  ' + r.target : '')),
            h('div', { class: 'sub', text: (r.detail ? r.detail + ' · ' : '') + r.date })));
}

function renderAudit(data, c) {
    if (!data.rows.length) c.appendChild(h('div', { class: 'empty', text: t('ui_audit_empty') }));
    pager(c, 'audit', data, 'rows', auditRow);
}

/* ---------------------------------------------------------------- storage log */
function renderStash(data, c) {
    if (!data.rows.length) { c.appendChild(h('div', { class: 'empty', text: t('ui_stash_empty') })); return; }
    data.rows.forEach((r) => {
        const took = r.action === 'take';
        c.appendChild(h('div', { class: 'row' },
            h('div', { class: 'main' },
                h('div', { class: 'name' }, h('span', { class: 'badge ' + (took ? 'warn' : 'good'), text: took ? t('ui_stash_take') : t('ui_stash_put') }), ' ', r.name),
                h('div', { class: 'sub', text: r.time ? new Date(r.time * 1000).toLocaleString() : '' })),
            h('div', { text: r.amount + 'x ' + r.item })));
    });
}

/* ---------------------------------------------------------------- settings (gangs) */
function renderSettings(data, c) {
    if (data.canEdit) {
        const label = h('input', { class: 'input', value: data.label, maxlength: String(data.maxName) });
        const tag = h('input', { class: 'input', value: data.tag, maxlength: String(data.maxTag), style: 'width:140px;text-transform:uppercase' });
        let color = data.color;
        const sw = h('div', { class: 'swatches' });
        data.colors.forEach((col) => {
            const s = h('div', { class: 'swatch' + (col === color ? ' on' : ''), style: 'background:' + col });
            s.addEventListener('click', () => { color = col; sw.querySelectorAll('.swatch').forEach((x) => x.classList.remove('on')); s.classList.add('on'); });
            sw.appendChild(s);
        });
        c.appendChild(h('div', { class: 'field' }, h('label', { text: t('ui_gang_name') }), label));
        c.appendChild(h('div', { class: 'field' }, h('label', { text: t('ui_gang_tag') }), tag));
        c.appendChild(h('div', { class: 'field' }, h('label', { text: t('ui_gang_color') }), sw));
        c.appendChild(h('button', { class: 'wood-btn', text: t('ui_save'), onClick: async () => {
            const res = await act('settings', { label: label.value, tag: tag.value, color });
            if (res.ok) refreshTab();
        } }));
    }
    c.appendChild(h('div', { class: 'section-title', text: t('ui_danger_zone') }));
    const row = h('div', { style: 'display:flex;gap:10px;flex-wrap:wrap' });
    row.appendChild(h('button', { class: 'wood-btn danger', text: t('ui_leave'), onClick: () =>
        confirmModal(t('ui_leave'), t('ui_leave_confirm'), async () => { await act('leave'); }, true) }));
    if (data.canDisband) {
        row.appendChild(h('button', { class: 'wood-btn danger', text: t('ui_disband'), onClick: () =>
            confirmModal(t('ui_disband'), t('ui_disband_confirm'), async () => { await act('disband', { confirm: true }); }, true) }));
    }
    c.appendChild(row);
}

/* ---------------------------------------------------------------- create a gang */
function renderCreate(create) {
    $('title').textContent = t('ui_create_title');
    $('subtitle').textContent = t('ui_type_gang');
    $('tabs').innerHTML = '';
    const c = $('content'); c.innerHTML = '';
    const input = h('input', { class: 'input', maxlength: String(create.max), placeholder: t('ui_gang_name') });
    const card = h('div', { class: 'center-card' },
        h('p', { text: t('ui_create_hint', money(create.cost), create.min, create.max) }),
        h('div', { class: 'field' }, h('label', { text: t('ui_gang_name') }), input),
        h('button', { class: 'wood-btn', text: t('ui_create'), onClick: async () => {
            const res = await api('createGang', { label: input.value });
            toast(res.msg, res.ok ? 'success' : 'error');
            if (res.ok) await api('reopen');
        } }));
    c.appendChild(card);
}

/* ---------------------------------------------------------------- invite */
function showInvite(inv) {
    const body = h('p', { text: t('ui_invite_text', inv.from, inv.society) });
    openModal(t('ui_invite_title'), body, [
        { label: t('ui_accept'), onClick: () => { closeModal(); api('inviteReply', { accepted: true }); } },
        { label: t('ui_decline'), cls: 'muted-btn', onClick: () => { closeModal(); api('inviteReply', { accepted: false }); } },
    ]);
    const ms = (Number(inv.seconds) || 0) * 1000;
    if (ms > 0) {
        setTimeout(() => {
            if (!$('modal-body').contains(body)) return; // already answered, or another window is open now
            closeModal();
            api('inviteReply', { accepted: false }); // releases the screen when only the invite was showing
        }, ms);
    }
}

/* ---------------------------------------------------------------- window messages */
function openMenu(msg) {
    S.mode = 'menu';
    document.body.classList.remove('invite-only');
    $('root').classList.remove('hidden');
    S.tab = 'overview';
    S.ledgerKind = '';
    if (msg.create) { S.view = null; renderCreate(msg.create); return; }
    S.view = msg.view;
    renderHeader(); renderTabs(); renderOverview();
}

window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.strings) { S.strings = d.strings; applyI18n(); }
    if (d.action === 'open') {
        closeModal();
        if (d.mode === 'admin') {
            if (window.openAdmin) window.openAdmin(d);
        } else if (d.mode === 'invite') {
            S.mode = 'invite';
            document.body.classList.add('invite-only');
            $('root').classList.add('hidden');
            showInvite(d.invite);
        } else {
            openMenu(d);
        }
    } else if (d.action === 'invite') {
        showInvite(d.invite);
    } else if (d.action === 'close') {
        closeModal();
        if (window.closeAdmin) window.closeAdmin();
        $('root').classList.add('hidden');
        document.body.classList.remove('invite-only');
        S.view = null;
    }
});

$('btn-close').addEventListener('click', () => api('close'));
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        if (!$('modal-layer').classList.contains('hidden')) {
            if (S.mode === 'invite') { closeModal(); api('inviteReply', { accepted: false }); } else closeModal();
        } else api('close');
    }
});
$('modal-layer').addEventListener('mousedown', (e) => { if (e.target === $('modal-layer') && S.mode !== 'invite') closeModal(); });
