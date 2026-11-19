'use strict';

const root = document.getElementById('root');
const $ = (id) => document.getElementById(id);

const state = { data: null, strings: {}, region: null, tab: 'taxes', pending: {}, ledger: null, busy: false };

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
const money = (n) => '$' + Number(n || 0).toFixed(2);
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
                await post('setTax', { region: region.id, category: t.key, rate: shown });
                delete state.pending[key];
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
            await post(endpoint, { region: region.id, amount });
            state.busy = false;
            input.value = '';
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
        if (canWithdraw && state.data.dailyLimit > 0) box.appendChild(el('div', 'hint', S('ui_daily_limit').replace('%s', money(state.data.dailyLimit))));
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

function render() {
    const d = state.data;
    if (!d) return;
    const region = currentRegion();
    if (!region) return;
    state.region = region.id;

    $('title').textContent = S('ui_title');
    $('subtitle').textContent = S('ui_subtitle');
    $('regionLabel').textContent = S('ui_region');
    $('roleLine').textContent = region.official ? S('ui_official') : S('ui_citizen');
    document.querySelectorAll('#tabs .tab').forEach((b) => {
        b.textContent = S('ui_tab_' + b.dataset.tab);
        b.classList.toggle('active', b.dataset.tab === state.tab);
    });

    setupDd($('regionDd'), d.regions.map((r) => ({ value: r.id, label: r.label })), region.id, (v) => {
        state.region = v;
        state.ledger = null;
        render();
        if (state.tab === 'treasury') loadLedger();
    });

    // keep what was typed in the amount box across a re-render
    const prev = document.getElementById('amountInput');
    const typed = prev ? prev.value : '';
    const box = $('content');
    box.textContent = '';
    if (state.tab === 'taxes') renderTaxes(region, box);
    else if (state.tab === 'treasury') renderTreasury(region, box);
    else renderMarket(region, box);
    const now = document.getElementById('amountInput');
    if (now && typed) now.value = typed;
}

async function loadLedger() {
    const region = currentRegion();
    if (!region) return;
    const id = region.id;
    const rows = await post('ledger', { region: id });
    if (state.region === id) {
        state.ledger = Array.isArray(rows) ? rows : [];
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
    state.region = (data.regions[0] || {}).id;
    state.tab = 'taxes';
    state.pending = {};
    state.ledger = null;
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
