'use strict';

const root = document.getElementById('root');
const $ = (id) => document.getElementById(id);

const state = { data: null, strings: {}, region: null, tab: 'taxes', pending: {}, ledger: null, remaining: null, busy: false, election: null, admin: null, adminSel: '', adminForm: null };

function post(endpoint, payload) {
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(payload || {}),
    }).then((r) => r.json()).catch(() => null);
}

function el(tag, className, text) {
    const e = document.createElement(tag);
    if (className) e.className = className;
    if (text !== undefined) e.textContent = text;
    return e;
}

const S = (k) => state.strings[k] || k;
const money = (n) => '$' + Number(n || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const pct = (r) => (Number(r) * 100).toFixed(1) + '%';

function currentRegion() {
    if (!state.data) return null;
    return state.data.regions.find((r) => r.id === state.region) || state.data.regions[0] || null;
}

/* ---------- custom dropdown (never a native select) ---------- */
function closeAllDd() {
    document.querySelectorAll('.dd.open').forEach((d) => d.classList.remove('open'));
}

function setupDd(container, options, value, onChange) {
    container.textContent = '';
    container.dataset.value = value;
    const current = options.find((o) => o.value === value) || options[0];
    const val = el('span', 'dd-value', current ? current.label : '');
    const arrow = el('span', 'dd-arrow', '▾');
    const menu = el('div', 'dd-menu');
    options.forEach((o) => {
        const opt = el('div', 'dd-opt' + (o.value === value ? ' selected' : ''), o.label);
        opt.addEventListener('mousedown', (e) => {
            e.preventDefault();
            e.stopPropagation();
            container.classList.remove('open');
            if (o.value !== container.dataset.value) onChange(o.value);
        });
        menu.appendChild(opt);
    });
    val.addEventListener('mousedown', (e) => {
        e.preventDefault();
        e.stopPropagation();
        const wasOpen = container.classList.contains('open');
        closeAllDd();
        if (!wasOpen) container.classList.add('open');
    });
    container.append(val, arrow, menu);
}

document.addEventListener('mousedown', (e) => {
    if (!e.target.closest || !e.target.closest('.dd')) closeAllDd();
});

/* ---------- rendering ---------- */
function renderTaxes(region, box) {
    box.appendChild(el('div', 'hint', S('ui_taxes_hint')));
    region.taxes.forEach((t) => {
        const key = `${region.id}|${t.key}`;
        const pending = state.pending[key];
        const shown = pending !== undefined ? pending : t.rate;
        const changed = pending !== undefined && Math.abs(pending - t.rate) > 1e-9;

        const row = el('div', 'row');
        const flex = el('div', 'row-flex');
        const left = el('div');
        left.appendChild(el('div', 'row-name', t.label));
        left.appendChild(el('div', 'sub', `${pct(t.min)} - ${pct(t.max)}`));
        flex.appendChild(left);

        const controls = el('div', 'rate-controls');
        if (region.official) {
            const step = state.data.step || 0.005;
            const minus = el('button', 'wood-btn step-btn', '−');
            const plus = el('button', 'wood-btn step-btn', '+');
            minus.type = plus.type = 'button';
            const setPending = (v) => {
                v = Math.min(t.max, Math.max(t.min, Math.round(v / step) * step));
                state.pending[key] = Math.round(v * 10000) / 10000;
                render();
            };
            minus.addEventListener('click', () => setPending(shown - step));
            plus.addEventListener('click', () => setPending(shown + step));
            controls.appendChild(minus);
            controls.appendChild(el('span', 'rate-value' + (changed ? ' changed' : ''), pct(shown)));
            controls.appendChild(plus);
            const apply = el('button', 'wood-btn small', S('ui_apply'));
            apply.type = 'button';
            apply.disabled = !changed || state.busy;
            apply.addEventListener('click', async () => {
                state.busy = true;
                const res = await post('setTax', { region: region.id, category: t.key, rate: shown });
                if (res && res.ok) delete state.pending[key]; // keep the chosen rate when the server said no
                state.busy = false;
                refresh();
            });
            controls.appendChild(apply);
        } else {
            controls.appendChild(el('span', 'rate-value', pct(t.rate)));
        }
        flex.appendChild(controls);
        row.appendChild(flex);
        box.appendChild(row);
    });
}

function fmtTime(ts) {
    const d = new Date(ts * 1000);
    return d.toLocaleDateString() + ' ' + d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

function renderTreasury(region, box) {
    const card = el('div', 'row balance-card');
    card.appendChild(el('div', 'balance-label', S('ui_balance')));
    card.appendChild(el('div', 'balance-num', region.balance === null || region.balance === undefined ? S('ui_hidden') : money(region.balance)));
    box.appendChild(card);

    const canWithdraw = region.official && state.data.canWithdraw;
    const canDeposit = region.official || state.data.donations;
    if (canWithdraw || canDeposit) {
        const row = el('div', 'input-row');
        const input = el('input', 'txt');
        input.type = 'text';
        input.id = 'amountInput';
        input.placeholder = S('ui_amount');
        input.maxLength = 12;
        row.appendChild(input);
        const act = (endpoint) => async () => {
            if (state.busy) return;
            const amount = parseFloat(input.value.replace(',', '.'));
            if (!(amount > 0)) return;
            state.busy = true;
            const res = await post(endpoint, { region: region.id, amount });
            state.busy = false;
            if (res && res.ok) input.value = ''; // keep the amount when the server said no
            refresh();
        };
        if (canWithdraw) {
            const w = el('button', 'wood-btn', S('ui_withdraw'));
            w.type = 'button';
            w.addEventListener('click', act('withdraw'));
            row.appendChild(w);
        }
        if (canDeposit) {
            const d = el('button', 'wood-btn', S('ui_deposit'));
            d.type = 'button';
            d.addEventListener('click', act('deposit'));
            row.appendChild(d);
        }
        box.appendChild(row);
        if (canWithdraw && state.data.dailyLimit > 0) {
            const remaining = state.remaining;
            box.appendChild(el('div', 'hint', typeof remaining === 'number'
                ? S('ui_remaining').replace('%s', money(remaining))
                : S('ui_daily_limit').replace('%s', money(state.data.dailyLimit))));
        }
        if (!region.official) box.appendChild(el('div', 'hint', S('ui_donate_hint')));
    }

    box.appendChild(el('div', 'section-title', S('ui_projects')));
    region.projects.forEach((p) => {
        const row = el('div', 'row');
        const flex = el('div', 'row-flex');
        const left = el('div');
        left.appendChild(el('div', 'row-name', p.label));
        const detail = p.active
            ? (p.expires === 0 ? S('ui_permanent') : S('ui_active_until').replace('%s', fmtTime(p.expires)))
            : `${S('ui_cost')} ${money(p.cost)}` + (p.days > 0 ? ` · ${p.days} ${S('ui_days')}` : '');
        left.appendChild(el('div', 'sub', detail));
        flex.appendChild(left);
        if (p.active) {
            flex.appendChild(el('span', 'pill good', '✓'));
        } else if (region.official) {
            const f = el('button', 'wood-btn small', S('ui_fund'));
            f.type = 'button';
            f.addEventListener('click', async () => {
                if (state.busy) return;
                state.busy = true;
                await post('fundProject', { region: region.id, project: p.id });
                state.busy = false;
                refresh();
            });
            flex.appendChild(f);
        }
        row.appendChild(flex);
        box.appendChild(row);
    });

    if (region.balance !== null && region.balance !== undefined) {
        box.appendChild(el('div', 'section-title', S('ui_ledger')));
        if (!state.ledger || state.ledger.length === 0) {
            box.appendChild(el('div', 'empty', S('ui_ledger_empty')));
        } else {
            state.ledger.forEach((l) => {
                const row = el('div', 'row');
                const top = el('div', 'row-flex');
                top.appendChild(el('span', 'row-name', S('kind_' + l.kind) === 'kind_' + l.kind ? l.kind : S('kind_' + l.kind)));
                const sign = l.amount > 0 ? '+' : '';
                top.appendChild(el('span', 'ledger-amount ' + (l.amount > 0 ? 'pos' : (l.amount < 0 ? 'neg' : '')), l.amount === 0 ? '' : sign + money(l.amount)));
                row.appendChild(top);
                if (l.reason) row.appendChild(el('div', 'ledger-reason', l.reason));
                row.appendChild(el('div', 'sub', `${l.actor} · ${fmtTime(l.created)}`));
                box.appendChild(row);
            });
        }
    }
}

function renderMarket(region, box) {
    box.appendChild(el('div', 'hint', S('ui_market_hint')));
    if (!region.movers.length) {
        box.appendChild(el('div', 'empty', S('ui_market_empty')));
        return;
    }
    region.movers.forEach((m) => {
        const row = el('div', 'row');
        const top = el('div', 'row-flex');
        top.appendChild(el('span', 'row-name', m.label));
        const diff = Math.round((m.multiplier - 1) * 100);
        top.appendChild(el('span', 'pill ' + (diff > 0 ? 'bad' : 'good'), (diff > 0 ? '+' : '') + diff + '%'));
        row.appendChild(top);
        box.appendChild(row);
    });
}

/* ---------- elections ---------- */
function renderElections(region, box) {
    box.appendChild(el('div', 'hint', S('ui_elections_hint')));
    const v = state.election;
    if (!v || v.region !== region.id) {
        box.appendChild(el('div', 'empty', S('ui_loading')));
        return;
    }

    const card = el('div', 'row');
    card.appendChild(el('div', 'balance-label', S('ui_mayor')));
    if (v.mayor) {
        card.appendChild(el('div', 'row-name', v.mayor.name));
        card.appendChild(el('div', 'sub', S('ui_term_ends').replace('%s', fmtTime(v.mayor.termEnd))));
    } else {
        card.appendChild(el('div', 'sub', S('ui_no_mayor')));
    }
    box.appendChild(card);

    const phase = v.phase;
    let status = S('ui_election_idle');
    if (phase === 'candidacy') status = S('ui_candidacy_open').replace('%s', fmtTime(v.phaseEnd));
    else if (phase === 'voting') status = S('ui_voting_open').replace('%s', fmtTime(v.phaseEnd));
    box.appendChild(el('div', 'section-title', status));

    const act = async (endpoint, payload) => {
        if (state.busy) return;
        state.busy = true;
        await post(endpoint, payload);
        state.busy = false;
        loadElection();
        refresh();
    };

    if (phase === 'candidacy' && !v.registered) {
        const row = el('div', 'input-row');
        const input = el('input', 'txt');
        input.type = 'text';
        input.placeholder = S('ui_platform');
        input.maxLength = v.maxPlatform || 140;
        row.appendChild(input);
        const btn = el('button', 'wood-btn', S('ui_register'));
        btn.type = 'button';
        btn.addEventListener('click', () => act('electionRegister', { region: region.id, platform: input.value }));
        row.appendChild(btn);
        box.appendChild(row);
        if (v.fee > 0) box.appendChild(el('div', 'hint', S('ui_register_fee').replace('%s', money(v.fee))));
    }

    box.appendChild(el('div', 'section-title', S('ui_candidates')));
    if (!v.candidates || !v.candidates.length) {
        box.appendChild(el('div', 'empty', S('ui_no_candidates')));
        return;
    }
    v.candidates.forEach((c) => {
        const row = el('div', 'row');
        const top = el('div', 'row-flex');
        top.appendChild(el('span', 'row-name', c.name));
        const right = el('div', 'rate-controls');
        if (typeof c.votes === 'number') right.appendChild(el('span', 'pill', c.votes + ' ' + S('ui_votes')));
        if (v.votedFor === c.id) {
            right.appendChild(el('span', 'pill on', '✓ ' + S('ui_your_vote')));
        } else if (phase === 'voting' && !v.votedFor) {
            const vote = el('button', 'wood-btn small', S('ui_vote'));
            vote.type = 'button';
            vote.addEventListener('click', () => act('electionVote', { region: region.id, candidate: c.id }));
            right.appendChild(vote);
        }
        if (c.mine && (phase === 'candidacy' || phase === 'voting')) {
            const out = el('button', 'wood-btn small', S('ui_withdraw_candidacy'));
            out.type = 'button';
            out.addEventListener('click', () => act('electionWithdraw', { region: region.id }));
            right.appendChild(out);
        }
        top.appendChild(right);
        row.appendChild(top);
        if (c.platform) row.appendChild(el('div', 'platform', c.platform));
        box.appendChild(row);
    });
}

async function loadElection() {
    const region = currentRegion();
    if (!region) return;
    const id = region.id;
    const v = await post('election', { region: id });
    if (state.region !== id) return;
    if (v && v.region) state.election = v;
    else if (!state.election || state.election.region !== id) state.election = { region: id, candidates: [], fee: 0, maxPlatform: 140 };
    if (state.tab === 'elections') render();
}

/* ---------- admin: towns ---------- */
const blankForm = () => ({ id: '', label: '', order: 99, lawJob: '', officials: [{ job: 'government', minGrade: 0 }], usePos: true, exists: false });
const formFrom = (r) => ({
    id: r.id, label: r.label, order: r.order, lawJob: r.lawJob || '', usePos: false, exists: true,
    custom: r.custom, overridden: r.overridden,
    officials: r.officials.map((o) => ({ job: o.job, minGrade: o.minGrade })),
    pos: [r.x, r.y, r.z].map((n) => Number(n).toFixed(0)).join(', '),
});

function field(labelText, input) {
    const f = el('div', 'field');
    f.appendChild(el('span', 'label', labelText));
    f.appendChild(input);
    return f;
}

function textInput(value, onInput, placeholder, disabled) {
    const i = el('input', 'txt');
    i.type = 'text';
    i.value = value === undefined || value === null ? '' : value;
    if (placeholder) i.placeholder = placeholder;
    i.disabled = !!disabled;
    i.addEventListener('input', () => onInput(i.value));
    return i;
}

function renderAdmin(box) {
    box.appendChild(el('div', 'hint', S('ui_admin_hint')));
    if (!state.admin) {
        box.appendChild(el('div', 'empty', S('ui_loading')));
        return;
    }
    if (!state.adminForm) state.adminForm = blankForm();
    const form = state.adminForm;

    const pick = el('div', 'region-row');
    pick.appendChild(el('span', 'label', S('ui_region')));
    const dd = el('div', 'dd');
    const options = [{ value: '', label: S('ui_admin_new') }].concat(state.admin.map((r) => ({ value: r.id, label: `${r.label} (${r.id})` })));
    setupDd(dd, options, state.adminSel, (v) => {
        state.adminSel = v;
        const r = state.admin.find((x) => x.id === v);
        state.adminForm = r ? formFrom(r) : blankForm();
        render();
    });
    pick.appendChild(dd);
    box.appendChild(pick);

    const top = el('div', 'field-row');
    top.appendChild(field(S('ui_admin_id'), textInput(form.id, (v) => { form.id = v; }, 'new_town', form.exists)));
    top.appendChild(field(S('ui_admin_label'), textInput(form.label, (v) => { form.label = v; })));
    box.appendChild(top);

    const mid = el('div', 'field-row');
    mid.appendChild(field(S('ui_admin_order'), textInput(form.order, (v) => { form.order = v; })));
    mid.appendChild(field(S('ui_admin_law'), textInput(form.lawJob, (v) => { form.lawJob = v; }, 'vallaw')));
    box.appendChild(mid);

    box.appendChild(el('div', 'section-title', S('ui_admin_officials')));
    form.officials.forEach((o, i) => {
        const row = el('div', 'official-row');
        row.appendChild(textInput(o.job, (v) => { o.job = v; }, S('ui_job')));
        row.appendChild(textInput(o.minGrade, (v) => { o.minGrade = v; }, S('ui_grade')));
        const rm = el('button', 'wood-btn small', '✕');
        rm.type = 'button';
        rm.addEventListener('click', () => { form.officials.splice(i, 1); render(); });
        row.appendChild(rm);
        box.appendChild(row);
    });
    if (form.officials.length < 6) {
        const add = el('button', 'wood-btn small', S('ui_admin_add'));
        add.type = 'button';
        add.addEventListener('click', () => { form.officials.push({ job: '', minGrade: 0 }); render(); });
        box.appendChild(add);
    }

    const posRow = el('div', 'row-flex');
    const pos = el('button', 'wood-btn small' + (form.usePos ? ' active' : ''), S('ui_admin_use_pos'));
    pos.type = 'button';
    pos.addEventListener('click', () => { form.usePos = !form.usePos; render(); });
    posRow.appendChild(pos);
    if (form.exists && form.pos) posRow.appendChild(el('span', 'sub', S('ui_admin_position').replace('%s', form.pos)));
    box.appendChild(posRow);

    const actions = el('div', 'input-row');
    const save = el('button', 'wood-btn', S('ui_admin_save'));
    save.type = 'button';
    save.disabled = state.busy;
    save.addEventListener('click', async () => {
        if (state.busy) return;
        state.busy = true;
        const res = await post('adminSave', { data: {
            id: String(form.id || '').trim().toLowerCase(), label: String(form.label || '').trim(),
            order: Number(form.order), lawJob: String(form.lawJob || '').trim(),
            officials: form.officials.filter((o) => String(o.job || '').trim()).map((o) => ({ job: String(o.job).trim(), minGrade: Number(o.minGrade) || 0 })),
            useMyPosition: !!form.usePos,
        } });
        state.busy = false;
        if (res && res.ok) {
            state.adminSel = String(form.id || '').trim().toLowerCase();
            state.adminForm = null;
            await loadAdmin();
            const r = state.admin.find((x) => x.id === state.adminSel);
            if (r) state.adminForm = formFrom(r);
            render();
            refresh();
        }
    });
    actions.appendChild(save);
    if (form.exists && (form.custom || form.overridden)) {
        const del = el('button', 'wood-btn', S('ui_admin_delete'));
        del.type = 'button';
        del.addEventListener('click', async () => {
            if (state.busy) return;
            state.busy = true;
            const res = await post('adminDelete', { id: form.id });
            state.busy = false;
            if (res && res.ok) {
                state.adminSel = '';
                state.adminForm = null;
                await loadAdmin();
                render();
                refresh();
            }
        });
        actions.appendChild(del);
    }
    box.appendChild(actions);
}

async function loadAdmin() {
    const list = await post('admin');
    state.admin = Array.isArray(list) ? list : [];
    if (!state.adminForm) state.adminForm = blankForm();
    if (state.tab === 'admin') render();
}

function render() {
    const d = state.data;
    if (!d) return;
    const region = currentRegion();
    if (!region) return;
    state.region = region.id;

    $('title').textContent = S('ui_title');
    $('subtitle').textContent = S('ui_subtitle');
    $('regionLabel').textContent = S('ui_region');
    $('roleLine').textContent = (region.official ? S('ui_official') : S('ui_citizen'))
        + (region.mayor ? ' · ' + S('ui_mayor') + ': ' + region.mayor : '');
    const tabShown = { elections: !!d.elections, admin: !!d.admin };
    if (tabShown[state.tab] === false) state.tab = 'taxes';
    document.querySelectorAll('#tabs .tab').forEach((b) => {
        b.textContent = S('ui_tab_' + b.dataset.tab);
        b.classList.toggle('hidden', tabShown[b.dataset.tab] === false);
        b.classList.toggle('active', b.dataset.tab === state.tab);
    });

    setupDd($('regionDd'), d.regions.map((r) => ({ value: r.id, label: r.label })), region.id, (v) => {
        state.region = v;
        state.ledger = null;
        state.remaining = null;
        state.election = null;
        render();
        if (state.tab === 'treasury') loadLedger();
        if (state.tab === 'elections') loadElection();
    });

    // keep what was typed in the amount box across a re-render
    const prev = document.getElementById('amountInput');
    const typed = prev ? prev.value : '';
    const box = $('content');
    box.textContent = '';
    if (state.tab === 'taxes') renderTaxes(region, box);
    else if (state.tab === 'treasury') renderTreasury(region, box);
    else if (state.tab === 'elections') renderElections(region, box);
    else if (state.tab === 'admin') renderAdmin(box);
    else renderMarket(region, box);
    const now = document.getElementById('amountInput');
    if (now && typed) now.value = typed;
}

async function loadLedger() {
    const region = currentRegion();
    if (!region) return;
    const id = region.id;
    const res = await post('ledger', { region: id });
    if (state.region === id) {
        state.ledger = res && Array.isArray(res.rows) ? res.rows : [];
        state.remaining = res && typeof res.remaining === 'number' ? res.remaining : null;
        if (state.tab === 'treasury') render();
    }
}

async function refresh() {
    const fresh = await post('panel');
    if (fresh && fresh.regions) {
        state.data = fresh;
        render();
        if (state.tab === 'treasury') loadLedger();
    }
}

function openUi(data, strings) {
    state.data = data;
    state.strings = strings || {};
    state.region = data.defaultRegion || (data.regions[0] || {}).id;
    state.tab = 'taxes';
    state.pending = {};
    state.ledger = null;
    state.remaining = null;
    state.election = null;
    state.admin = null;
    state.adminSel = '';
    state.adminForm = null;
    state.busy = false;
    root.classList.remove('hidden');
    render();
}

function closeUi() {
    closeAllDd();
    root.classList.add('hidden');
}

window.addEventListener('message', (event) => {
    const msg = event.data || {};
    if (msg.action === 'open') openUi(msg.data, msg.strings);
    else if (msg.action === 'close') closeUi();
});

document.querySelectorAll('#tabs .tab').forEach((b) => {
    b.addEventListener('click', () => {
        closeAllDd();
        state.tab = b.dataset.tab;
        render();
        if (state.tab === 'treasury') loadLedger();
        if (state.tab === 'elections') loadElection();
        if (state.tab === 'admin') loadAdmin();
    });
});

$('closeBtn').addEventListener('click', () => {
    closeUi();
    post('close');
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !root.classList.contains('hidden')) {
        closeUi();
        post('close');
    }
});
