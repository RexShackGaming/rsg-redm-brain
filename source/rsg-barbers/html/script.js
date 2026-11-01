const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-barbers';
const $ = (id) => document.getElementById(id);
const state = { open: false, saving: false, tabs: [], active: 0, s: {} };

function post(name, data = {}) {
    return fetch(`https://${RES}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).then((r) => r.json()).catch(() => ({}));
}

const fmt = (str, ...args) => { let i = 0; return (str || '').replace(/%s/g, () => args[i++]); };
const t = (k) => state.s[k] || k;

function display(f) {
    if (f.kind === 'style') return f.value === 0 ? t('none') : fmt(t('style_n'), f.value);
    if (f.kind === 'color') return f.max === 0 ? t('none') : fmt(t('color_n'), f.value);
    if (f.kind === 'percent') return `${f.value}%`;
    return `${f.value}`;
}

function sub(f) {
    if (f.kind === 'percent' || f.max === 0) return '';
    return `${f.value - f.min + 1} / ${f.max - f.min + 1}`;
}

function rowHtml(f, i) {
    const disabled = f.max <= f.min;
    const bar = f.kind === 'percent'
        ? `<div class="bar" data-i="${i}"><div class="fill" style="width:${((f.value - f.min) / (f.max - f.min || 1)) * 100}%"></div></div>` : '';
    const desc = sub(f);
    return `<div class="row${disabled ? ' disabled' : ''}" data-i="${i}">
        <div class="row-text">
            <div class="row-title">${f.label}</div>
            ${desc ? `<div class="row-desc">${desc}</div>` : ''}
            ${bar}
        </div>
        <div class="stepper">
            <div class="step" data-i="${i}" data-d="-1">&#8249;</div>
            <div class="value">${display(f)}</div>
            <div class="step" data-i="${i}" data-d="1">&#8250;</div>
        </div>
    </div>`;
}

function render() {
    $('tabs').innerHTML = state.tabs.map((tab, i) =>
        `<div class="tab${i === state.active ? ' active' : ''}" data-tab="${i}">${tab.label}</div>`).join('');
    const fields = state.tabs[state.active]?.fields || [];
    $('list').innerHTML = fields.map(rowHtml).join('');
}

function refreshRow(i) {
    const fields = state.tabs[state.active].fields;
    const old = $('list').querySelector(`.row[data-i="${i}"]`);
    if (!old) return;
    const tmp = document.createElement('div');
    tmp.innerHTML = rowHtml(fields[i], i);
    old.replaceWith(tmp.firstElementChild);
}

let pending = Promise.resolve();
function setValue(i, value) {
    const fields = state.tabs[state.active].fields;
    const f = fields[i];
    if (!f || f.max <= f.min) return;
    // wrap styles/colours, clamp the rest
    if (f.kind === 'style' || f.kind === 'color') {
        if (value > f.max) value = f.min; else if (value < f.min) value = f.max;
    } else {
        value = Math.max(f.min, Math.min(f.max, value));
    }
    if (value === f.value) return;
    f.value = value;
    refreshRow(i);
    // serialise preview calls so the ped never applies them out of order
    pending = pending.then(() => post('change', { key: f.key, value })).then((res) => {
        if (res && res.update) {
            const j = fields.findIndex((x) => x.key === res.update.key);
            if (j >= 0) { Object.assign(fields[j], res.update); refreshRow(j); }
        }
    });
}

function step(i, dir) {
    const f = state.tabs[state.active].fields[i];
    if (f) setValue(i, f.value + dir * (f.step || 1));
}

// stepper clicks (hold to repeat)
let holdTimer = null;
function stopHold() { clearTimeout(holdTimer); clearInterval(holdTimer); holdTimer = null; }
$('list').addEventListener('mousedown', (e) => {
    const btn = e.target.closest('.step');
    if (btn) {
        const i = +btn.dataset.i, d = +btn.dataset.d;
        step(i, d);
        holdTimer = setTimeout(() => { holdTimer = setInterval(() => step(i, d), 110); }, 400);
        return;
    }
    const bar = e.target.closest('.bar');
    if (bar) {
        const f = state.tabs[state.active].fields[+bar.dataset.i];
        const rect = bar.getBoundingClientRect();
        const pct = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
        const s = f.step || 1;
        setValue(+bar.dataset.i, Math.round((f.min + pct * (f.max - f.min)) / s) * s);
    }
});
window.addEventListener('mouseup', stopHold);

// mouse wheel over a row changes it
$('list').addEventListener('wheel', (e) => {
    const row = e.target.closest('.row');
    if (!row || !e.shiftKey) return;
    e.preventDefault();
    step(+row.dataset.i, e.deltaY < 0 ? 1 : -1);
}, { passive: false });

$('tabs').addEventListener('click', (e) => {
    const tab = e.target.closest('.tab');
    if (!tab) return;
    state.active = +tab.dataset.tab;
    render();
    $('list').scrollTop = 0;
});

function close() {
    if (!state.open || state.saving) return;
    state.open = false;
    $('app').classList.add('hidden');
    post('close');
}

async function save() {
    if (state.saving) return;
    state.saving = true;
    $('payBtn').disabled = true;
    $('payBtn').textContent = t('ui_saving');
    const res = await post('save');
    state.saving = false;
    $('payBtn').disabled = false;
    $('payBtn').textContent = t('ui_pay');
    if (res && (res.ok || !res.keepOpen)) {
        state.open = false;
        $('app').classList.add('hidden');
    }
}

$('closeBtn').addEventListener('click', close);
$('cancelBtn').addEventListener('click', close);
$('payBtn').addEventListener('click', save);

window.addEventListener('keydown', (e) => {
    if (!state.open) return;
    if (e.key === 'Escape' || e.key === 'Backspace') close();
    else if (e.key === 'Enter') save();
});

window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'open') {
        state.open = true;
        state.saving = false;
        state.s = d.strings || {};
        state.tabs = d.tabs || [];
        state.active = 0;
        $('title').textContent = t('barber_title');
        $('subtitle').textContent = d.shop || '';
        $('priceLabel').textContent = t('ui_price');
        $('priceValue').textContent = `$${d.price}`;
        $('cancelBtn').textContent = t('ui_cancel');
        $('payBtn').textContent = t('ui_pay');
        $('payBtn').disabled = false;
        $('hint').textContent = t('ui_hint');
        $('app').classList.toggle('left', d.align === 'left' || d.align === 'top-left');
        render();
        $('app').classList.remove('hidden');
    } else if (d.action === 'close') {
        state.open = false;
        state.saving = false;
        stopHold();
        $('app').classList.add('hidden');
    }
});
