'use strict';
/* rsg-society admin panel. Uses the helpers of script.js (h, t, api, toast, makeDd, openModal, confirmModal, money ...).
   The server decides everything: this file only asks and shows what comes back. */

const AD = {
    tab: 'dashboard',
    token: 0,
    soc: null,            // { name, label, sub } while a society is open
    player: null,         // citizen id while a player is open
    societyFilter: { search: '', type: '' },
    playerSearch: '',
    fineFilter: { status: '', society: '' },
    auditSociety: '',
};

const AD_TABS = ['dashboard', 'societies', 'players', 'desks', 'fines', 'audit', 'tools'];
const SUBS = ['overview', 'members', 'ranks', 'ledger', 'audit', 'fines'];

const admBox = () => $('adm-content');
const permLabel = (p) => S.strings['ui_perm_' + p] || p;
const kindLabel = (k) => S.strings['ui_kind_' + k] || k;
const actLabel = (a) => S.strings['ui_act_' + a] || a;
const num = (v) => Number(String(v === undefined || v === null ? '' : v).replace(',', '.'));

async function adminTab(tab, arg) {
    return api('adminTab', { tab, arg: arg || {} });
}

async function adminAct(action, data, quiet) {
    const res = await api('adminAct', { action, data: data || {} });
    if (res.msg && !quiet) toast(res.msg, res.ok ? 'success' : 'error');
    return res;
}

/* ---------------------------------------------------------------- small builders */
function stat(label, value, cls) {
    return h('div', { class: 'stat' }, h('div', { class: 'label', text: label }), h('div', { class: 'value ' + (cls || ''), text: String(value) }));
}

function section(title) {
    return h('div', { class: 'section-title', text: title });
}

function empty(text) {
    return h('div', { class: 'empty', text });
}

function badge(text, cls) {
    return h('span', { class: 'badge ' + (cls || ''), text });
}

function field(label, control) {
    return h('div', { class: 'field' }, h('label', { text: label }), control);
}

function rowEl(opts) {
    const r = h('div', { class: 'row' + (opts.onClick ? ' click' : '') },
        opts.lead || null,
        h('div', { class: 'main' },
            h('div', { class: 'name', text: opts.name || '' }),
            opts.sub ? h('div', { class: 'sub', text: opts.sub }) : null),
        opts.actions ? h('div', { class: 'actions' }, opts.actions) : null);
    if (opts.onClick) r.addEventListener('click', (e) => { if (!e.target.closest('.actions')) opts.onClick(); });
    return r;
}

function dot(on, color) {
    const d = h('span', { class: 'dot' + (on ? ' on' : '') });
    if (color) { d.style.background = color; d.style.borderColor = color; }
    return d;
}

function switchEl(on, onToggle, locked) {
    const el = h('div', { class: 'switch' + (on ? ' on' : '') + (locked ? ' locked' : '') },
        h('span', { class: 'track' }), h('span', { text: on ? t('ui_on') : t('ui_off') }));
    if (!locked) el.addEventListener('click', onToggle);
    return el;
}

function btn(label, onClick, cls) {
    return h('button', { class: 'wood-btn ' + (cls || ''), text: label, onClick });
}

function debounce(fn, ms) {
    let timer;
    return (...args) => { clearTimeout(timer); timer = setTimeout(() => fn(...args), ms); };
}

function setLoading() {
    const c = admBox();
    c.innerHTML = '';
    c.appendChild(empty(t('ui_loading')));
}

function setError(res) {
    const c = admBox();
    c.innerHTML = '';
    c.appendChild(empty((res && res.msg) || t('ui_no_answer')));
}

/* A list that loads more rows with a button (rows carry an id, the server pages with "before"). */
function makePager(box, tab, base, first, rowFn, emptyText) {
    const list = h('div');
    const more = h('div', { class: 'more' });
    box.appendChild(list);
    box.appendChild(more);
    let last = 0;
    let shown = 0;

    function show(res) {
        (res.rows || []).forEach((row) => { list.appendChild(rowFn(row)); last = row.id; shown++; });
        more.innerHTML = '';
        if (res.more) {
            more.appendChild(btn(t('ui_load_more'), async (e) => {
                e.target.disabled = true;
                const next = await adminTab(tab, Object.assign({}, base, { before: last }));
                if (!next.ok) { toast(next.msg, 'error'); e.target.disabled = false; return; }
                show(next);
            }, 'small'));
        }
        if (shown === 0 && emptyText) list.appendChild(empty(emptyText));
    }
    show(first);
}

/* ---------------------------------------------------------------- shell */
function renderAdminTabs() {
    const bar = $('adm-tabs');
    bar.innerHTML = '';
    AD_TABS.forEach((id) => {
        const label = id === 'fines' ? t('ui_tab_fines') : id === 'audit' ? t('ui_tab_audit') : t('ui_adm_tab_' + id);
        bar.appendChild(h('div', { class: 'tab' + (id === AD.tab ? ' active' : ''), text: label, onClick: () => {
            AD.tab = id; AD.soc = null; AD.player = null;
            renderAdminTabs(); loadAdminTab();
        } }));
    });
}

function tabArg(tab) {
    if (tab === 'societies') return { search: AD.societyFilter.search, type: AD.societyFilter.type, offset: 0 };
    if (tab === 'players') return { search: AD.playerSearch };
    if (tab === 'fines') return { status: AD.fineFilter.status, society: AD.fineFilter.society };
    if (tab === 'audit') return { society: AD.auditSociety };
    return {};
}

async function loadAdminTab() {
    closeDropdowns();
    if (AD.tab === 'societies' && AD.soc) return loadSociety();
    if (AD.tab === 'players' && AD.player) return loadPlayer();
    const tab = AD.tab;
    const token = ++AD.token;
    setLoading();
    const res = await adminTab(tab, tabArg(tab));
    if (token !== AD.token) return;
    if (!res.ok) return setError(res);
    ({ dashboard: renderDashboard, societies: renderSocieties, players: renderPlayers, desks: renderDesks, fines: renderFines, audit: renderAudit, tools: renderTools })[tab](res);
}

window.openAdmin = function (msg) {
    S.mode = 'admin';
    document.body.classList.remove('invite-only');
    $('root').classList.add('hidden');
    $('admin-root').classList.remove('hidden');
    $('adm-title').textContent = t('ui_adm_title');
    $('adm-subtitle').textContent = t('ui_adm_subtitle');
    AD.tab = 'dashboard'; AD.soc = null; AD.player = null; AD.token++;
    renderAdminTabs();
    renderDashboard(msg.dashboard || {});
};

window.closeAdmin = function () {
    $('admin-root').classList.add('hidden');
    closeDropdowns();
};

$('adm-close').addEventListener('click', () => api('close'));

/* ---------------------------------------------------------------- dashboard */
function renderDashboard(d) {
    const c = admBox();
    c.innerHTML = '';
    (d.warnings || []).forEach((k) => c.appendChild(h('div', { class: 'notice', text: t(k) })));
    c.appendChild(h('div', { class: 'stats' },
        stat(t('ui_adm_stat_societies'), (d.jobs || 0) + (d.gangs || 0)),
        stat(t('ui_adm_stat_jobs'), d.jobs || 0),
        stat(t('ui_adm_stat_gangs'), d.gangs || 0),
        stat(t('ui_adm_stat_funds'), money(d.funds), 'ok'),
        stat(t('ui_adm_stat_unpaid'), (d.fineCount || 0) + ' / ' + money(d.fineOwed), d.fineCount ? 'bad' : ''),
        stat(t('ui_adm_stat_desks'), d.desks || 0)));

    c.appendChild(section(t('ui_adm_richest')));
    if (!(d.top || []).length) c.appendChild(empty(t('ui_adm_no_societies')));
    (d.top || []).forEach((s) => c.appendChild(rowEl({
        name: s.label, sub: s.type === 'gang' ? t('ui_type_gang') : t('ui_type_job'),
        actions: [h('span', { class: 'amount-pos', text: money(s.balance) })],
        onClick: () => openSociety(s.name, s.label),
    })));

    c.appendChild(section(t('ui_adm_recent')));
    if (!(d.recent || []).length) c.appendChild(empty(t('ui_audit_empty')));
    (d.recent || []).forEach((r) => c.appendChild(auditRow(r, true)));
}

/* ---------------------------------------------------------------- societies list */
function renderSocieties(res) {
    const c = admBox();
    c.innerHTML = '';
    const search = h('input', { class: 'input', placeholder: t('ui_adm_search_soc'), value: AD.societyFilter.search, maxlength: '40' });
    const typeDd = makeDd([
        { value: '', label: t('ui_adm_all_types') },
        { value: 'job', label: t('ui_type_job') },
        { value: 'gang', label: t('ui_type_gang') },
    ], AD.societyFilter.type, (v) => { AD.societyFilter.type = v; reload(); }, true);
    const listBox = h('div');

    c.appendChild(h('div', { class: 'toolbar' },
        h('div', { class: 'grow' }, search), typeDd,
        btn(t('ui_adm_new_job'), newJobModal), btn(t('ui_adm_new_gang'), newGangModal)));
    c.appendChild(listBox);

    let offset = 0;
    function fill(r, append) {
        if (!append) { listBox.innerHTML = ''; offset = 0; }
        (r.rows || []).forEach((s) => {
            listBox.appendChild(rowEl({
                lead: dot(true, s.type === 'gang' ? s.color : null),
                name: s.label + (s.tag ? '  [' + s.tag + ']' : ''),
                sub: (s.type === 'gang' ? t('ui_type_gang') : t('ui_type_job')) + ' · ' + t('ui_member_count', s.members) + ' · ' + t('ui_payroll') + ': ' + (s.payroll ? t('ui_on') : t('ui_off')),
                actions: [h('span', { class: s.balance > 0 ? 'amount-pos' : 'muted', text: money(s.balance) })],
                onClick: () => openSociety(s.name, s.label),
            }));
            offset++;
        });
        const old = listBox.querySelector('.more');
        if (old) old.remove();
        if (offset === 0) listBox.appendChild(empty(t('ui_adm_no_results')));
        if (r.more) {
            const more = h('div', { class: 'more' }, btn(t('ui_load_more'), async () => {
                const next = await adminTab('societies', { search: AD.societyFilter.search, type: AD.societyFilter.type, offset });
                if (!next.ok) return toast(next.msg, 'error');
                fill(next, true);
            }, 'small'));
            listBox.appendChild(more);
        }
    }
    async function reload() {
        const r = await adminTab('societies', { search: AD.societyFilter.search, type: AD.societyFilter.type, offset: 0 });
        if (!r.ok) return toast(r.msg, 'error');
        fill(r, false);
    }
    search.addEventListener('input', debounce(() => { AD.societyFilter.search = search.value; reload(); }, 300));
    fill(res, false);
}

async function newJobModal() {
    const res = await adminTab('job_options');
    if (!res.ok) return toast(res.msg, 'error');
    const dd = makeDd(res.jobs || [], (res.jobs && res.jobs[0]) ? res.jobs[0].value : '');
    openModal(t('ui_adm_new_job'), h('div', null, h('p', { class: 'italic', text: t('ui_adm_new_job_hint') }), field(t('ui_adm_job_pick'), dd)), [
        { label: t('ui_create_short'), onClick: async () => {
            const job = ddValue(dd);
            if (!job) return;
            const r = await adminAct('create_job', { job });
            if (r.ok) { closeModal(); openSociety(r.society); }
        } },
        { label: t('ui_cancel'), cls: 'muted-btn' },
    ]);
}

function newGangModal() {
    const label = h('input', { class: 'input', maxlength: '40', placeholder: t('ui_gang_name') });
    const leader = h('input', { class: 'input', maxlength: '50', placeholder: t('ui_adm_target') });
    const colors = (S.adminColors && S.adminColors.length) ? S.adminColors : ['#e63946', '#f4a261', '#e9c46a', '#2a9d8f', '#264653', '#8338ec', '#3a86ff', '#ff006e', '#06d6a0', '#adb5bd'];
    let color = colors[0];
    const sw = h('div', { class: 'swatches' });
    colors.forEach((col) => {
        const el = h('div', { class: 'swatch' + (col === color ? ' on' : '') });
        el.style.background = col;
        el.addEventListener('click', () => { color = col; sw.querySelectorAll('.swatch').forEach((x) => x.classList.remove('on')); el.classList.add('on'); });
        sw.appendChild(el);
    });
    openModal(t('ui_adm_new_gang'), h('div', null,
        field(t('ui_gang_name'), label),
        field(t('ui_adm_leader'), leader),
        field(t('ui_gang_color'), sw)), [
        { label: t('ui_create_short'), onClick: async () => {
            const r = await adminAct('create_gang', { label: label.value, leader: leader.value, color });
            if (r.ok) { closeModal(); openSociety(r.society); }
        } },
        { label: t('ui_cancel'), cls: 'muted-btn' },
    ]);
}

/* ---------------------------------------------------------------- one society */
function openSociety(name, label) {
    AD.tab = 'societies';
    AD.player = null;
    AD.soc = { name, label: label || name, sub: 'overview' };
    renderAdminTabs();
    loadSociety();
}

function backToList() {
    AD.soc = null;
    loadAdminTab();
}

async function loadSociety() {
    closeDropdowns();
    const soc = AD.soc;
    const token = ++AD.token;
    const c = admBox();
    c.innerHTML = '';

    const sub = h('div', { class: 'tabs sub-tabs' });
    SUBS.forEach((id) => {
        const label = id === 'overview' ? t('ui_tab_overview') : id === 'members' ? t('ui_tab_members') : id === 'ranks' ? t('ui_tab_ranks')
            : id === 'ledger' ? t('ui_ledger') : id === 'audit' ? t('ui_tab_audit') : t('ui_tab_fines');
        sub.appendChild(h('div', { class: 'tab' + (id === soc.sub ? ' active' : ''), text: label, onClick: () => { soc.sub = id; loadSociety(); } }));
    });
    const titleEl = h('div', { class: 'soc-title', text: soc.label });
    c.appendChild(h('div', { class: 'toolbar' }, btn('< ' + t('ui_adm_back'), backToList, 'small'), titleEl, h('div', { class: 'grow' })));
    c.appendChild(sub);
    const body = h('div');
    c.appendChild(body);
    body.appendChild(empty(t('ui_loading')));

    const res = await adminTab('s_' + soc.sub, { name: soc.name });
    if (token !== AD.token) return;
    body.innerHTML = '';
    if (!res.ok) { body.appendChild(empty(res.msg || t('ui_no_answer'))); return; }
    if (res.label) { soc.label = res.label; titleEl.textContent = res.label + (res.tag ? '  [' + res.tag + ']' : ''); }
    if (res.colors) S.adminColors = res.colors;
    ({ overview: subOverview, members: subMembers, ranks: subRanks, ledger: subLedger, audit: subAudit, fines: subFines })[soc.sub](res, body);
}

const refreshSociety = () => loadSociety();

async function socAct(action, data, after) {
    const res = await adminAct(action, Object.assign({ name: AD.soc.name }, data || {}));
    if (res.ok) {
        if (res.gone) { AD.soc = null; return loadAdminTab(); }
        if (after) after(res); else refreshSociety();
    }
    return res;
}

function subOverview(r, body) {
    body.appendChild(h('div', { class: 'stats' },
        stat(t('ui_balance'), money(r.balance), r.balance > 0 ? 'ok' : ''),
        stat(t('ui_tab_members'), r.members),
        stat(t('ui_payroll'), r.payroll ? t('ui_on') : t('ui_off')),
        stat(t('ui_adm_stat_desks'), r.desks)));
    if (r.type === 'gang') {
        body.appendChild(h('div', { class: 'italic', text: t('ui_adm_owner') + ': ' + (r.ownerName || '-') }));
    }

    // funds
    const amount = h('input', { class: 'input', placeholder: t('ui_amount') + ' (' + t('ui_max') + ' ' + money(r.maxFunds) + ')', maxlength: '14' });
    const reason = h('input', { class: 'input', placeholder: t('ui_reason'), maxlength: '120' });
    const funds = (mode) => async () => {
        const v = num(amount.value);
        if (!(v > 0)) return toast(t('ui_adm_bad_amount'), 'error');
        const res = await socAct('funds', { mode, amount: v, reason: reason.value });
        if (res && !res.ok) amount.focus();
    };
    body.appendChild(section(t('ui_adm_funds')));
    body.appendChild(h('div', { class: 'form-row' },
        field(t('ui_amount'), amount), field(t('ui_reason'), reason),
        btn(t('ui_adm_funds_add'), funds('add')), btn(t('ui_adm_funds_remove'), funds('remove'), 'danger')));

    // payroll + storage
    body.appendChild(section(t('ui_payroll')));
    const payrollRow = h('div', { class: 'form-row' },
        switchEl(r.payroll, () => socAct('payroll', { enabled: !r.payroll })),
        btn(t('ui_adm_open_storage'), () => socAct('storage_open', {}, () => {})));
    if (r.type === 'gang') {
        payrollRow.appendChild(btn(t('ui_adm_run_payroll'), () => socAct('run_payroll', {}, () => refreshSociety())));
    }
    body.appendChild(payrollRow);
    if (!r.payrollEnabled) body.appendChild(h('div', { class: 'notice', text: t('ui_payroll_disabled') }));

    // gang settings
    if (r.type === 'gang') {
        const label = h('input', { class: 'input', value: r.label, maxlength: String(r.maxName || 20) });
        const tag = h('input', { class: 'input', value: r.tag || '', maxlength: String(r.maxTag || 5) });
        let color = r.color;
        const sw = h('div', { class: 'swatches' });
        (r.colors || []).forEach((col) => {
            const el = h('div', { class: 'swatch' + (col === color ? ' on' : '') });
            el.style.background = col;
            el.addEventListener('click', () => { color = col; sw.querySelectorAll('.swatch').forEach((x) => x.classList.remove('on')); el.classList.add('on'); });
            sw.appendChild(el);
        });
        body.appendChild(section(t('ui_tab_settings')));
        body.appendChild(h('div', { class: 'form-row' }, field(t('ui_gang_name'), label), field(t('ui_gang_tag'), tag)));
        body.appendChild(field(t('ui_gang_color'), sw));
        body.appendChild(btn(t('ui_save'), () => socAct('gang_info', { label: label.value, tag: tag.value, color })));
    }

    // danger zone
    body.appendChild(section(t('ui_danger_zone')));
    if (r.type === 'gang') {
        body.appendChild(btn(t('ui_disband'), () => confirmModal(t('ui_disband'), t('ui_adm_disband_confirm', r.label, money(r.balance)),
            () => socAct('disband', { confirm: true }), true), 'danger'));
    } else {
        const del = btn(t('ui_adm_delete_society'), () => confirmModal(t('ui_adm_delete_society'), t('ui_adm_delete_confirm', r.label, money(r.balance)),
            () => socAct('delete_job', { confirm: true }), true), 'danger');
        if (r.inConfig) { del.disabled = true; body.appendChild(h('div', { class: 'notice', text: t('ui_adm_cfg_hint') })); }
        body.appendChild(del);
    }
}

function subMembers(r, body) {
    const grades = r.grades || [];
    const options = grades.map((g) => ({ value: g.level, label: g.name + (g.boss ? ' (' + t('ui_boss') + ')' : '') }));
    const target = h('input', { class: 'input', placeholder: t('ui_adm_target'), maxlength: '50' });
    const lowest = grades.length ? grades[0].level : 0;
    const levelDd = makeDd(options, lowest, null, true);
    body.appendChild(h('div', { class: 'form-row' },
        field(t('ui_adm_add_member'), target), field(t('ui_rank'), levelDd),
        btn(t('ui_hire'), async () => {
            if (!target.value.trim()) return target.focus();
            const res = await socAct('member_add', { target: target.value.trim(), level: Number(ddValue(levelDd)) });
            if (res && !res.ok) target.focus();
        })));

    if (!(r.rows || []).length) return body.appendChild(empty(t('ui_no_members')));
    r.rows.forEach((m) => {
        const dd = makeDd(options, m.level, async (v) => {
            const res = await socAct('member_level', { cid: m.cid, level: Number(v) });
            if (res && !res.ok) refreshSociety(); // put the dropdown back to the real rank
        }, true);
        const actions = [dd];
        if (r.gang && !m.owner) actions.push(btn(t('ui_adm_set_owner'), () => confirmModal(t('ui_adm_set_owner'), t('ui_transfer_confirm', m.name), () => socAct('set_owner', { cid: m.cid }))));
        actions.push(btn(t('ui_fire'), () => confirmModal(t('ui_fire'), t('ui_adm_remove_confirm', m.name, AD.soc.label), () => socAct('member_remove', { cid: m.cid }), true), 'danger small'));
        body.appendChild(rowEl({
            lead: dot(m.online), name: m.name + (m.owner ? '  *' : ''), sub: m.cid + ' · ' + m.grade + (m.online ? ' · ' + t('ui_online') : ''), actions,
        }));
    });
}

function subRanks(r, body) {
    body.appendChild(h('div', { class: 'italic', text: r.gang ? t('ui_ranks_hint_gang') : t('ui_ranks_hint_job') }));
    if (r.gang) {
        const nm = h('input', { class: 'input', placeholder: t('ui_adm_rank_name'), maxlength: '24' });
        body.appendChild(h('div', { class: 'form-row' }, field(t('ui_rank_add'), nm), btn(t('ui_rank_add'), async () => {
            const res = await socAct('rank_add', { rankName: nm.value });
            if (res && !res.ok) nm.focus();
        })));
    }
    (r.grades || []).slice().reverse().forEach((g) => {
        const set = new Set(g.perms || []);
        const card = h('div', { class: 'card' });
        let nameInput, payInput;
        const head = h('div', { class: 'card-head' });
        head.appendChild(badge(String(g.level), g.boss ? 'boss' : ''));
        if (r.gang && !g.boss) {
            nameInput = h('input', { class: 'input narrow', value: g.name, maxlength: '24' });
            payInput = h('input', { class: 'input narrow', value: String(g.pay), maxlength: '8', title: t('ui_wages') });
            head.appendChild(nameInput);
            head.appendChild(h('span', { class: 'muted', text: t('ui_wages') + ' $' }));
            head.appendChild(payInput);
        } else {
            head.appendChild(h('span', { class: 'rank-name', text: g.name }));
            if (r.gang) head.appendChild(h('span', { class: 'muted', text: t('ui_wages') + ' ' + money(g.pay) }));
        }
        if (g.boss) head.appendChild(badge(t('ui_boss'), 'boss'));
        card.appendChild(head);

        if (g.boss) {
            card.appendChild(h('div', { class: 'italic', text: t('ui_all_perms') }));
        } else {
            const chips = h('div', { class: 'chips' });
            (r.allPerms || []).forEach((p) => {
                const chip = h('div', { class: 'chip' + (set.has(p) ? ' on' : ''), text: permLabel(p) });
                chip.addEventListener('click', () => {
                    if (set.has(p)) { set.delete(p); chip.classList.remove('on'); } else { set.add(p); chip.classList.add('on'); }
                });
                chips.appendChild(chip);
            });
            card.appendChild(chips);
            const actions = h('div', { class: 'card-actions' });
            actions.appendChild(btn(t('ui_save'), () => socAct('rank_save', {
                level: g.level, perms: Array.from(set),
                meta: r.gang ? { name: nameInput.value, pay: num(payInput.value) } : undefined,
            }), 'small'));
            if (r.gang) {
                actions.appendChild(btn(t('ui_rank_delete'), () => confirmModal(t('ui_rank_delete'), t('ui_rank_delete_confirm', g.name),
                    () => socAct('rank_delete', { level: g.level }), true), 'small danger'));
            }
            card.appendChild(actions);
        }
        body.appendChild(card);
    });
}

function subLedger(r, body) {
    makePager(body, 's_ledger', { name: AD.soc.name }, r, (e) => rowEl({
        name: kindLabel(e.kind) + (e.note ? ' · ' + e.note : ''),
        sub: (e.actor ? e.actor + ' · ' : '') + e.date + ' · ' + t('ui_balance') + ' ' + money(e.balance),
        actions: [h('span', { class: e.amount >= 0 ? 'amount-pos' : 'amount-neg', text: (e.amount >= 0 ? '+' : '') + money(e.amount) })],
    }), t('ui_ledger_empty'));
}

function auditRow(e, withSociety) {
    const who = [e.actor, e.target ? '> ' + e.target : '', e.detail].filter(Boolean).join(' ');
    return rowEl({
        name: actLabel(e.action) + (withSociety && e.society ? ' · ' + e.society : ''),
        sub: who,
        actions: [h('span', { class: 'muted', text: e.date })],
    });
}

function subAudit(r, body) {
    makePager(body, 's_audit', { name: AD.soc.name }, r, (e) => auditRow(e, false), t('ui_audit_empty'));
}

function fineRow(f, withSociety, reload) {
    const status = f.status === 'unpaid' ? ['bad', t('ui_fine_unpaid')] : f.status === 'paid' ? ['good', t('ui_fine_paid')] : ['', t('ui_fine_void')];
    const actions = [badge(status[1], status[0]), h('span', { text: money(f.paid) + ' / ' + money(f.amount) })];
    if (f.status === 'unpaid') {
        actions.push(btn(t('ui_void'), () => confirmModal(t('ui_void'), t('ui_void_confirm', f.target), async () => {
            const res = await adminAct('fine_void', { id: f.id });
            if (res.ok) reload();
        }, true), 'small danger'));
    }
    return rowEl({
        name: (f.target || f.cid) + (withSociety ? ' · ' + f.society : ''),
        sub: [f.reason, f.issuer, f.date].filter(Boolean).join(' · '),
        actions,
    });
}

function subFines(r, body) {
    makePager(body, 's_fines', { name: AD.soc.name }, r, (f) => fineRow(f, false, refreshSociety), t('ui_fines_empty'));
}

/* ---------------------------------------------------------------- players */
function renderPlayers(res) {
    const c = admBox();
    c.innerHTML = '';
    const search = h('input', { class: 'input', placeholder: t('ui_adm_search_player'), value: AD.playerSearch, maxlength: '40' });
    const listBox = h('div');
    c.appendChild(h('div', { class: 'toolbar' }, h('div', { class: 'grow' }, search)));
    c.appendChild(h('div', { class: 'italic', text: t('ui_adm_players_hint') }));
    c.appendChild(listBox);

    function fill(r) {
        listBox.innerHTML = '';
        if (!(r.rows || []).length) return listBox.appendChild(empty(t('ui_adm_no_results')));
        r.rows.forEach((p) => listBox.appendChild(rowEl({
            lead: dot(p.online),
            name: p.name + (p.src ? '  [' + p.src + ']' : ''),
            sub: p.cid + (p.gang ? ' · ' + p.gang : ''),
            onClick: () => { AD.player = p.cid; loadPlayer(); },
        })));
    }
    search.addEventListener('input', debounce(async () => {
        AD.playerSearch = search.value;
        const r = await adminTab('players', { search: AD.playerSearch });
        if (!r.ok) return toast(r.msg, 'error');
        fill(r);
    }, 300));
    fill(res);
}

async function loadPlayer() {
    closeDropdowns();
    const token = ++AD.token;
    setLoading();
    const r = await adminTab('player', { cid: AD.player });
    if (token !== AD.token) return;
    if (!r.ok) { AD.player = null; return setError(r); }
    const c = admBox();
    c.innerHTML = '';
    c.appendChild(h('div', { class: 'toolbar' },
        btn('< ' + t('ui_adm_back'), () => { AD.player = null; loadAdminTab(); }, 'small'),
        h('div', { class: 'soc-title', text: r.name }), badge(r.online ? t('ui_online') : t('ui_offline'), r.online ? 'good' : ''),
        h('div', { class: 'grow' })));
    c.appendChild(h('div', { class: 'stats' }, stat(t('ui_adm_citizen'), r.cid), stat(t('ui_adm_owed'), money(r.owed), r.owed > 0 ? 'bad' : '')));

    c.appendChild(section(t('ui_adm_memberships')));
    if (!r.memberships.length) c.appendChild(empty(t('ui_adm_no_memberships')));
    r.memberships.forEach((m) => c.appendChild(rowEl({
        name: m.label, sub: (m.type === 'gang' ? t('ui_type_gang') : t('ui_type_job')) + ' · ' + m.grade,
        actions: m.boss ? [badge(t('ui_boss'), 'boss')] : [],
        onClick: () => openSociety(m.name, m.label),
    })));

    c.appendChild(section(t('ui_tab_fines')));
    if (!r.fines.length) c.appendChild(empty(t('ui_fines_empty')));
    r.fines.forEach((f) => c.appendChild(rowEl({
        name: f.society + ' · ' + money(f.left),
        sub: [f.reason, f.date].filter(Boolean).join(' · '),
        actions: [btn(t('ui_void'), () => confirmModal(t('ui_void'), t('ui_void_confirm', r.name), async () => {
            const res = await adminAct('fine_void', { id: f.id });
            if (res.ok) loadPlayer();
        }, true), 'small danger')],
    })));
    if (r.fines.length) {
        c.appendChild(h('div', { style: 'margin-top:10px' }, btn(t('ui_adm_forgive'), () => confirmModal(t('ui_adm_forgive'), t('ui_adm_forgive_confirm', r.name), async () => {
            const res = await adminAct('fines_forgive', { cid: r.cid });
            if (res.ok) loadPlayer();
        }, true), 'danger')));
    }
}

/* ---------------------------------------------------------------- desks */
function renderDesks(res) {
    const c = admBox();
    c.innerHTML = '';
    const socDd = makeDd(res.societies || [], (res.societies && res.societies[0]) ? res.societies[0].value : '');
    const label = h('input', { class: 'input', placeholder: t('ui_adm_desk_label'), maxlength: '80' });
    c.appendChild(h('div', { class: 'form-row' },
        field(t('ui_adm_society'), socDd), field(t('ui_adm_desk_label'), label),
        btn(t('ui_adm_desk_add'), async () => {
            const society = ddValue(socDd);
            if (!society) return;
            const r = await adminAct('desk_add', { name: society, label: label.value });
            if (r.ok) loadAdminTab();
        })));
    c.appendChild(h('div', { class: 'italic', text: t('ui_adm_desk_hint') }));

    if (!(res.rows || []).length) return c.appendChild(empty(t('ui_adm_desks_empty')));
    res.rows.forEach((d) => {
        const actions = [badge(d.config ? t('ui_adm_desk_cfg') : t('ui_adm_desk_game'), d.config ? '' : 'good'),
            btn(t('ui_adm_desk_goto'), () => adminAct('desk_goto', { id: d.id }, true), 'small')];
        if (!d.config) {
            actions.push(btn(t('ui_adm_desk_remove'), () => confirmModal(t('ui_adm_desk_remove'), t('ui_adm_desk_remove_confirm', d.label), async () => {
                const r = await adminAct('desk_remove', { id: d.id });
                if (r.ok) loadAdminTab();
            }, true), 'small danger'));
        }
        c.appendChild(rowEl({
            name: d.label + ' · ' + d.societyLabel,
            sub: d.x.toFixed(1) + ', ' + d.y.toFixed(1) + ', ' + d.z.toFixed(1),
            actions,
        }));
    });
}

/* ---------------------------------------------------------------- global fines + audit */
function socFilterOptions(list) {
    return [{ value: '', label: t('ui_adm_all_societies') }].concat(list || []);
}

function renderFines(res) {
    const c = admBox();
    c.innerHTML = '';
    const listBox = h('div');
    async function reload() {
        const r = await adminTab('fines', { status: AD.fineFilter.status, society: AD.fineFilter.society });
        if (!r.ok) return toast(r.msg, 'error');
        fill(r);
    }
    function fill(r) {
        listBox.innerHTML = '';
        makePager(listBox, 'fines', { status: AD.fineFilter.status, society: AD.fineFilter.society }, r, (f) => fineRow(f, true, reload), t('ui_fines_empty'));
    }
    const statusDd = makeDd([
        { value: '', label: t('ui_filter_all') }, { value: 'unpaid', label: t('ui_fine_unpaid') },
        { value: 'paid', label: t('ui_fine_paid') }, { value: 'void', label: t('ui_fine_void') },
    ], AD.fineFilter.status, (v) => { AD.fineFilter.status = v; reload(); }, true);
    const socDd = makeDd(socFilterOptions(res.societies), AD.fineFilter.society, (v) => { AD.fineFilter.society = v; reload(); }, true);
    c.appendChild(h('div', { class: 'toolbar' }, statusDd, socDd, h('div', { class: 'grow' })));
    c.appendChild(listBox);
    fill(res);
}

function renderAudit(res) {
    const c = admBox();
    c.innerHTML = '';
    const listBox = h('div');
    async function reload() {
        const r = await adminTab('audit', { society: AD.auditSociety });
        if (!r.ok) return toast(r.msg, 'error');
        fill(r);
    }
    function fill(r) {
        listBox.innerHTML = '';
        makePager(listBox, 'audit', { society: AD.auditSociety }, r, (e) => auditRow(e, true), t('ui_audit_empty'));
    }
    const socDd = makeDd(socFilterOptions(res.societies), AD.auditSociety, (v) => { AD.auditSociety = v; reload(); }, true);
    c.appendChild(h('div', { class: 'toolbar' }, socDd, h('div', { class: 'grow' })));
    c.appendChild(listBox);
    fill(res);
}

/* ---------------------------------------------------------------- tools */
function renderTools(r) {
    const c = admBox();
    c.innerHTML = '';
    const yn = (v) => (v ? t('ui_on') : t('ui_off'));
    c.appendChild(section(t('ui_system')));
    c.appendChild(h('div', { class: 'stats' },
        stat(t('ui_adm_version'), r.version),
        stat(t('ui_adm_stat_societies'), r.societies),
        stat(t('ui_payroll'), yn(r.payroll) + ' / ' + r.gangInterval + ' min'),
        stat(t('ui_adm_paycheck'), yn(r.paycheck), r.paycheck ? 'ok' : 'bad'),
        stat(t('ui_adm_autodb'), yn(r.autoDatabase)),
        stat(t('ui_adm_logging'), yn(r.logging))));

    c.appendChild(section(t('ui_adm_migrate')));
    c.appendChild(h('div', { class: 'italic', text: t('ui_adm_migrate_hint') }));
    c.appendChild(h('div', { class: 'form-row' }, btn(t('ui_adm_migrate'), () => confirmModal(t('ui_adm_migrate'), t('ui_adm_migrate_hint'), () => adminAct('migrate'))),
        btn(t('ui_adm_reload'), () => adminAct('reload'))));
    c.appendChild(h('div', { class: 'italic', text: t('ui_adm_reload_hint') }));

    c.appendChild(section(t('ui_adm_prune')));
    const days = h('input', { class: 'input', value: String(r.pruneDays > 0 ? r.pruneDays : 90), maxlength: '4' });
    c.appendChild(h('div', { class: 'form-row' }, field(t('ui_adm_prune_days'), days),
        btn(t('ui_adm_prune'), () => {
            const n = Math.floor(num(days.value));
            confirmModal(t('ui_adm_prune'), t('ui_adm_prune_confirm', n), () => adminAct('prune', { days: n }), true);
        }, 'danger')));
}
