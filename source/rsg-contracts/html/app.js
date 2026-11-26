const $ = (id) => document.getElementById(id);
let L = {}, limits = {}, state = null, tab = 'mine', paper = null, items = null, busy = false, pending = null;
let form = { type: 'supply' };

const post = (name, data) => fetch(`https://${typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-contracts'}/${name}`,
    { method: 'POST', body: JSON.stringify(data || {}) }).then((r) => r.json()).catch(() => null);

// all player text goes through textContent, never innerHTML
function el(tag, cls, text) {
    const n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text !== undefined) n.textContent = text;
    return n;
}
function button(text, onClick, cls) {
    const b = el('button', 'wood' + (cls ? ' ' + cls : ''), text);
    b.onclick = onClick;
    return b;
}
const money = (v) => '$' + Number(v).toFixed(2);
const span = (s) => `${Math.floor(s / 3600)}h ${Math.floor((s % 3600) / 60)}m`;

function ask(text, run) {
    pending = run;
    $('modal-title').textContent = L.ui_confirm_title;
    $('modal-text').textContent = text;
    $('modal-back').textContent = L.ui_back;
    $('modal-ok').textContent = L.ui_confirm;
    $('modal').classList.remove('hidden');
}
const closeModal = () => { pending = null; $('modal').classList.add('hidden'); };
$('modal-back').onclick = closeModal;
$('modal-ok').onclick = () => { const run = pending; closeModal(); if (run) run(); };

async function act(name, data) {
    if (busy) return false;
    busy = true;
    const r = await post('action', { name, data });
    busy = false;
    if (r && r.state) state = r.state;
    if (r && r.ok && name === 'create') { form = { type: 'supply' }; tab = 'mine'; }
    // a failed create keeps the form as typed
    if (!(name === 'create' && !(r && r.ok))) render();
    return r && r.ok;
}

function card(c) {
    const box = el('div', 'item');
    const top = el('div', 'top');
    top.append(el('div', 'name', `#${c.id} ${c.title}`), el('div', 'badge', L['ui_status_' + c.status]));
    box.append(top);
    const lines = [
        `${L.ui_buyer}: ${c.buyer}  •  ${L.ui_worker}: ${c.worker}`,
        `${L.ui_pay}: ${money(c.pay)}  •  ${L.ui_deposit}: ${money(c.deposit)}`,
    ];
    if (c.item) lines.push(`${L.ui_goods}: ${c.quantity}x ${c.item}`);
    if (c.status === 'offered') lines.push(`${L.ui_deadline}: ${c.hours}h`);
    if (c.status !== 'closed' && !paper) lines.push(`${L.ui_time_left}: ${span(c.secondsLeft)}`);
    lines.forEach((t) => box.append(el('div', 'meta', t)));
    if (c.details) box.append(el('div', 'details', c.details));
    return box;
}

function actionsFor(c) {
    const list = [];
    const add = (label, name, confirm, extra) => list.push(button(label, () => {
        const run = () => act(name, Object.assign({ id: c.id }, extra));
        if (confirm) ask(`${label}: #${c.id} ${c.title} (${money(c.pay)} / ${money(c.deposit)})`, run); else run();
    }, name === 'giveup' || name === 'decline' ? 'muted' : ''));
    if (c.role === 'other') {
        add(L.ui_rule_worker, 'rule', true, { winner: 'worker' });
        add(L.ui_rule_buyer, 'rule', true, { winner: 'buyer' });
    } else if (c.status === 'offered') {
        if (c.role === 'worker') { add(L.ui_sign, 'sign', true); add(L.ui_decline, 'decline', true); }
        else add(L.ui_withdraw, 'decline', true);
    } else if (c.status === 'active') {
        if (c.role === 'worker') {
            if (c.item) {
                add(L.ui_deliver, 'deliver', true);
                if (!state.atOffice) list[list.length - 1].disabled = true;
            } else add(L.ui_finish, 'finish', true);
            add(L.ui_giveup, 'giveup', true);
        } else if (!c.item) add(L.ui_approve, 'approve', true);
        if (c.cancel === 'mine') { const b = button(L.ui_cancel_waiting, null, 'muted'); b.disabled = true; list.push(b); }
        else add(c.cancel === 'theirs' ? L.ui_agree_cancel : L.ui_cancel, 'cancel', true);
    } else if (c.status === 'review' && c.role === 'buyer') {
        add(L.ui_approve, 'approve', true);
        add(L.ui_dispute, 'dispute', true);
    }
    return list;
}

function listView(list, empty) {
    const body = $('body');
    if (!list.length) body.append(el('div', 'empty', empty));
    list.forEach((c) => {
        const box = card(c);
        const row = el('div', 'actions');
        row.append(...actionsFor(c));
        if (row.children.length) box.append(row);
        body.append(box);
    });
}

function collectView() {
    const body = $('body');
    if (!state.claims.length) return body.append(el('div', 'empty', L.ui_empty_collect));
    state.claims.forEach((c) => {
        const box = el('div', 'item');
        box.append(el('div', 'name', c.item ? `${c.amount}x ${c.item}` : money(c.cash)), el('div', 'meta', `#${c.contract}`));
        body.append(box);
    });
    const b = button(L.ui_collect, () => act('collect'));
    b.disabled = !state.atOffice;
    body.append(b);
    if (!state.atOffice) body.append(el('div', 'hint', L.ui_office_only));
}

// HTML dropdown with search (native <select> crashes RedM)
function dropdown(options, key) {
    const dd = el('div', 'dd'), input = el('input'), menu = el('div', 'dd-menu');
    const current = options.find((o) => o.value === form[key]);
    input.value = current ? current.label : '';
    input.placeholder = L.ui_search;
    input.autocomplete = 'off';
    const fill = (q) => {
        menu.textContent = '';
        options.filter((o) => o.label.toLowerCase().includes(q.toLowerCase())).slice(0, 100).forEach((o) => {
            const opt = el('div', 'dd-opt', o.label);
            opt.onmousedown = (e) => { e.preventDefault(); form[key] = o.value; input.value = o.label; dd.classList.remove('open'); input.blur(); };
            menu.append(opt);
        });
    };
    input.onfocus = () => { fill(''); dd.classList.add('open'); };
    input.onclick = input.onfocus;
    input.oninput = () => { form[key] = null; fill(input.value); dd.classList.add('open'); };
    input.onblur = () => dd.classList.remove('open');
    dd.append(input, menu);
    return dd;
}

function field(label, node) {
    const f = el('div', 'field');
    f.append(el('label', 'f', label), node);
    return f;
}
function bound(key, max, tag) {
    const i = el(tag || 'input');
    i.value = form[key] || '';
    if (max) i.maxLength = max;
    i.autocomplete = 'off';
    i.oninput = () => { form[key] = i.value; };
    return i;
}

function newView() {
    const body = $('body');
    const types = el('div', 'actions field');
    ['supply', 'job'].forEach((t) => types.append(button(L['ui_' + t], () => { form.type = t; render(); }, form.type === t ? '' : 'muted')));
    body.append(types);
    if (!state.nearby.length) { form.target = null; body.append(el('div', 'hint', L.ui_no_nearby)); }
    else {
        if (!state.nearby.includes(form.target)) form.target = null;
        body.append(field(L.ui_player, dropdown(state.nearby.map((id) => ({ value: id, label: `ID ${id}` })), 'target')));
    }
    body.append(field(L.ui_subject, bound('title', limits.maxTitle)));
    if (form.type === 'supply') {
        const g = el('div', 'grid');
        g.append(field(L.ui_item, dropdown(items || [], 'item')), field(`${L.ui_quantity} (1-${limits.maxQuantity})`, bound('quantity', 5)));
        body.append(g);
    }
    body.append(field(L.ui_details, bound('details', limits.maxDetails, 'textarea')));
    const g = el('div', 'grid');
    g.append(field(`${L.ui_pay} (${limits.minPay}-${limits.maxPay})`, bound('pay', 9)),
        field(`${L.ui_deposit} (0-${limits.maxDeposit})`, bound('deposit', 9)));
    body.append(g, field(`${L.ui_hours} (${limits.minHours}-${limits.maxHours})`, bound('hours', 4)));
    body.append(el('div', 'hint', L.ui_send_hint));
    const send = button(L.ui_send, () => {
        const data = Object.assign({}, form, { deposit: form.deposit || 0 });
        ask(`${L.ui_send}: ${form.title || ''} (${money(Number(form.pay) || 0)})`, () => act('create', data));
    });
    send.disabled = !state.nearby.length;
    body.append(send);
}

function render() {
    const nav = $('tabs');
    nav.textContent = '';
    $('body').textContent = '';
    if (paper) {
        $('heading').textContent = L.ui_paper;
        $('body').append(card(paper));
        return;
    }
    $('heading').textContent = L.ui_title;
    const tabs = ['mine', 'new', 'collect'];
    if (state.arbiter) tabs.push('disputes');
    if (!tabs.includes(tab)) tab = 'mine';
    tabs.forEach((t) => {
        let text = L['ui_tab_' + t];
        if (t === 'collect' && state.claims.length) text += ` (${state.claims.length})`;
        nav.append(button(text, () => switchTab(t), t === tab ? 'on' : 'muted'));
    });
    if (tab === 'mine') listView(state.contracts, L.ui_empty);
    else if (tab === 'new') newView();
    else if (tab === 'collect') collectView();
    else listView(state.disputes, L.ui_empty_disputes);
}

async function switchTab(t) {
    tab = t;
    const r = await post('refresh');
    if (r && r.state) state = r.state;
    if (t === 'new' && !items) { const i = await post('items'); if (i && i.items) items = i.items; }
    if (tab === t) render();
}

const close = () => { $('root').classList.add('hidden'); closeModal(); post('close'); };
$('close').onclick = close;
document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape' || $('root').classList.contains('hidden')) return;
    if (!$('modal').classList.contains('hidden')) closeModal(); else close();
});

window.addEventListener('message', (e) => {
    const d = e.data;
    if (d.action === 'close') { $('root').classList.add('hidden'); closeModal(); return; }
    if (d.action !== 'open') return;
    L = d.labels; limits = d.limits; paper = d.paper || null; state = d.state || null; tab = d.tab || 'mine';
    busy = false;
    closeModal();
    $('root').classList.remove('hidden');
    render();
});
