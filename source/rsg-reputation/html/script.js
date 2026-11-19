'use strict';

const root = document.getElementById('root');
const $ = (id) => document.getElementById(id);

let state = { data: null, strings: {}, onlyKnown: true };

function post(endpoint, payload) {
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(payload || {}),
    }).catch(() => {});
}

function el(tag, className, text) {
    const e = document.createElement(tag);
    if (className) e.className = className;
    if (text !== undefined) e.textContent = text;
    return e;
}

function signed(n) {
    return n > 0 ? `+${n}` : String(n);
}

// fills a bar that is centred on 0: positive grows right (good), negative grows left (bad)
function setCentreFill(fill, value, min, max) {
    const half = 50;
    fill.classList.remove('stat-good', 'stat-bad');
    if (value >= 0) {
        const pct = max > 0 ? Math.min(1, value / max) * half : 0;
        fill.style.left = '50%';
        fill.style.width = `${pct}%`;
        fill.classList.add('stat-good');
    } else {
        const pct = min < 0 ? Math.min(1, value / min) * half : 0;
        fill.style.left = `${50 - pct}%`;
        fill.style.width = `${pct}%`;
        fill.classList.add('stat-bad');
    }
}

function priceText(mod) {
    const pct = Math.round(mod * 100);
    return `${state.strings.ui_prices} ${signed(pct)}%`;
}

function buildRow(r) {
    const row = el('div', r.type === 'town' ? 'row town' : 'row');
    const top = el('div', 'row-top');
    top.appendChild(el('span', 'row-name', r.label));
    top.appendChild(el('span', 'row-value', signed(r.standing)));
    row.appendChild(top);

    const bar = el('div', 'bar slim');
    bar.appendChild(el('div', 'mid'));
    const fill = el('div', 'fill');
    bar.appendChild(fill);
    row.appendChild(bar);
    setCentreFill(fill, r.standing, state.data.standingMin, state.data.standingMax);

    const sub = el('div', 'row-sub');
    sub.appendChild(el('span', 'row-tier', r.tier));
    const pills = el('div', 'pills');
    if (r.hostile) pills.appendChild(el('span', 'pill bad', state.strings.ui_hostile));
    if (r.priceModifier !== 0) {
        pills.appendChild(el('span', r.priceModifier > 0 ? 'pill bad' : 'pill good', priceText(r.priceModifier)));
    }
    sub.appendChild(pills);
    row.appendChild(sub);
    return row;
}

function render() {
    const d = state.data;
    const s = state.strings;
    if (!d) return;

    $('title').textContent = s.ui_title;
    $('subtitle').textContent = s.ui_subtitle;
    $('honorLabel').textContent = s.ui_honor;
    $('standingLabel').textContent = s.ui_standing;
    $('honorValue').textContent = signed(d.honor);
    $('honorTier').textContent = d.honorTier;
    $('honorMin').textContent = `${s.ui_infamy} ${d.honorMin}`;
    $('honorMax').textContent = `${d.honorMax} ${s.ui_fame}`;
    $('filterBtn').textContent = state.onlyKnown ? s.ui_show_all : s.ui_only_known;
    setCentreFill($('honorFill'), d.honor, d.honorMin, d.honorMax);

    const list = $('list');
    list.textContent = '';
    let shown = 0;

    const known = (r) => r.standing !== 0;
    const regions = d.regions.filter((r) => !state.onlyKnown || known(r));

    // keep a state's heading when it or one of its towns is shown
    const states = d.regions.filter((r) => r.type === 'state');
    const sectionOrder = [];
    states.forEach((st) => {
        const towns = regions.filter((r) => r.type === 'town' && r.parent === st.id);
        const stateShown = regions.some((r) => r.id === st.id);
        if (stateShown || towns.length) sectionOrder.push({ st, stateShown, towns });
    });
    // towns with no known state (should not happen with the default config)
    const orphan = regions.filter((r) => r.type === 'town' && !states.some((st) => st.id === r.parent));

    sectionOrder.forEach((sec) => {
        const stateRegion = sec.stateShown ? sec.st : null;
        if (stateRegion) { list.appendChild(buildRow(stateRegion)); shown++; }
        else { list.appendChild(el('div', 'group-title', sec.st.label)); }
        sec.towns.forEach((t) => { list.appendChild(buildRow(t)); shown++; });
    });
    orphan.forEach((t) => { list.appendChild(buildRow(t)); shown++; });

    $('empty').textContent = s.ui_empty;
    $('empty').classList.toggle('hidden', shown > 0);
}

function openUi(data, strings) {
    state.data = data;
    state.strings = strings || {};
    state.onlyKnown = true;
    root.classList.remove('hidden');
    render();
}

function closeUi() {
    root.classList.add('hidden');
}

window.addEventListener('message', (event) => {
    const msg = event.data || {};
    if (msg.action === 'open') openUi(msg.data, msg.strings);
    else if (msg.action === 'close') closeUi();
});

$('filterBtn').addEventListener('click', () => {
    state.onlyKnown = !state.onlyKnown;
    render();
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
