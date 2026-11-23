const app = document.getElementById('app');
const $ = (id) => document.getElementById(id);

let state = null;
let T = {};
let imagePath = '';
let batchEndsAt = null;  // local ms timestamp
let batchTotal = 0;
let batchPaused = null;  // {remaining,total} when the fire is out mid batch
let tickTimer = null;
let fuelEndsAt = null;  // local ms timestamp while burning
let fuelStatic = 0;     // seconds when not burning
const qtyMemory = {};    // item -> last typed amount
let category = null;     // selected recipe tab (null = all)

const t = (k, fb) => T[k] || fb || k;
const resName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-cooking';

function post(endpoint, data = {}) {
    return fetch(`https://${resName}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).catch(() => {});
}
let busy = false; // one action at a time: the server drops presses that arrive within 300ms
const act = async (action, data = {}) => {
    if (busy) return;
    busy = true;
    app.classList.add('busy');
    try { await post('action', { action, data }); }
    finally { busy = false; app.classList.remove('busy'); }
};

function fmt(sec) {
    sec = Math.max(0, Math.floor(sec));
    const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60;
    const mm = String(m).padStart(2, '0'), ss = String(s).padStart(2, '0');
    return h > 0 ? `${h}:${mm}:${ss}` : `${mm}:${ss}`;
}

function img(name) { return imagePath + esc(name); }
const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

function applyLocale() {
    document.querySelectorAll('[data-t]').forEach((el) => {
        const k = el.getAttribute('data-t');
        if (T[k]) el.textContent = T[k];
    });
    document.querySelectorAll('[data-t-title]').forEach((el) => {
        const k = el.getAttribute('data-t-title');
        if (T[k]) el.title = T[k];
    });
}

/* ---------------- render ---------------- */
function render() {
    if (!state) return;
    const recipe = state.recipes.find((r) => r.key === state.recipe);
    const editable = state.canUse;

    $('locked').classList.toggle('hidden', state.canUse);
    $('title').textContent = t('ui_title', 'Stove');
    $('fire-divider').classList.toggle('hidden', !state.usesFuel);
    $('fire-card').classList.toggle('hidden', !state.usesFuel);
    renderXp();
    $('btn-back').classList.toggle('invisible', !recipe || !editable);

    // left column
    $('recipe-picker').classList.toggle('hidden', !!recipe);
    $('recipe-active').classList.toggle('hidden', !recipe);
    if (!recipe) renderPicker(editable);
    else renderActive(recipe, editable);

    // right column
    renderStatus(recipe);
}

function renderXp() {
    $('xp-level').textContent = state.level;
    const fill = $('xp-fill');
    if (state.nextXp === undefined || state.nextXp === null) {
        fill.style.width = '100%';
        $('xp-text').textContent = `${state.xp} ${t('ui_xp', 'xp')} · ${t('ui_max_level')}`;
    } else {
        const pct = Math.min(100, ((state.xp - state.levelXp) / (state.nextXp - state.levelXp)) * 100);
        fill.style.width = pct + '%';
        $('xp-text').textContent = `${state.xp} / ${state.nextXp} ${t('ui_xp', 'xp')}`;
    }
}

function renderPicker(editable) {
    const list = $('recipe-list');
    list.innerHTML = '';
    // category tabs
    const cats = [];
    state.recipes.forEach((r) => { if (r.category && !cats.includes(r.category)) cats.push(r.category); });
    if (category && !cats.includes(category)) category = null;
    const tabs = $('cat-tabs');
    tabs.innerHTML = '';
    tabs.classList.toggle('hidden', cats.length < 2);
    [null, ...cats].forEach((c) => {
        const b = document.createElement('button');
        b.className = 'cat-tab' + (c === category ? ' active' : '');
        b.textContent = c === null ? t('ui_all', 'All') : c;
        b.addEventListener('click', () => { category = c; renderPicker(editable); });
        tabs.appendChild(b);
    });
    state.recipes.filter((r) => !category || r.category === category).forEach((r) => {
        const unlocked = state.level >= (r.level || 1);
        const can = editable && unlocked;
        const row = document.createElement('div');
        row.className = 'row' + (can ? ' clickable' : ' disabled');
        const tags = r.ingredients.map((i) => `<span class="pill">${i.perBatch}x ${esc(i.label)}</span>`).join('');
        row.innerHTML = `
            <div class="badge-icon"><img src="${img(r.output.image)}" alt=""></div>
            <div class="row-main">
                <div class="row-title">${esc(r.label)}</div>
                <div class="row-desc">${t('ui_makes')} ${r.output.amount}x ${esc(r.output.label)} · ${t('ui_batch_time')} ${fmt(r.time)}</div>
                <div class="ing-tags">${tags}</div>
            </div>
            ${unlocked
                ? `<button class="wood-btn small" ${can ? '' : 'disabled'}>${t('ui_select')}</button>`
                : `<span class="pill lock">${t('ui_requires')} ${r.level}</span>`}`;
        if (can) row.addEventListener('click', () => act('selectRecipe', { recipe: r.key }));
        list.appendChild(row);
    });
}

function renderActive(recipe, editable) {
    $('ra-img').src = img(recipe.output.image);
    $('ra-label').textContent = recipe.label;
    $('ra-desc').textContent = `${t('ui_makes')} ${recipe.output.amount}x ${recipe.output.label} · ${t('ui_batch_time')} ${fmt(recipe.time)}`;
    $('btn-change').disabled = !editable || !(state.hopperEmpty && state.output === 0 && !state.batch);

    const hopper = $('hopper');
    // keep focus on an input while refreshing
    const focused = document.activeElement && document.activeElement.dataset ? document.activeElement.dataset.item : null;
    hopper.innerHTML = '';

    recipe.ingredients.forEach((ing) => {
        const pct = Math.min(100, (ing.loaded / ing.capacity) * 100);
        const cls = ing.loaded < ing.perBatch ? 'stat-bad' : (pct < 35 ? 'stat-warn' : 'stat-good');
        const space = ing.capacity - ing.loaded;
        const maxLoad = Math.max(0, Math.min(space, ing.have));
        let qty = (qtyMemory[ing.item] !== undefined) ? qtyMemory[ing.item] : Math.min(ing.perBatch, maxLoad);
        qty = Math.max(0, Math.min(qty, maxLoad));

        const row = document.createElement('div');
        row.className = 'row hopper-row';
        row.innerHTML = `
            <div class="badge-icon"><img src="${img(ing.image)}" alt=""></div>
            <div class="row-main">
                <div class="row-title">${esc(ing.label)}</div>
                <div class="row-desc">${ing.perBatch} ${t('ui_per_batch')}</div>
                <div class="track"><div class="fill ${cls}" style="width:${pct}%"></div></div>
                <div class="meta">
                    <span>${t('ui_loaded')} <b>${ing.loaded} / ${ing.capacity}</b></span>
                    <span>${t('ui_have')} <b>${ing.have}</b></span>
                </div>
            </div>
            <div class="controls">
                <div class="qty">
                    <button data-d="-1">−</button>
                    <input type="number" min="0" max="${maxLoad}" value="${qty}" data-item="${esc(ing.item)}">
                    <button data-d="1">+</button>
                </div>
                <button class="wood-btn small muted" data-max>${t('ui_load_all')}</button>
                <button class="wood-btn small" data-load ${!editable || maxLoad <= 0 ? 'disabled' : ''}>${t('ui_load')}</button>
                <span class="spacer"></span>
                <button class="wood-btn small muted" data-unload ${!editable || ing.loaded <= 0 ? 'disabled' : ''}>${t('ui_unload')}</button>
            </div>`;

        const input = row.querySelector('input');
        const setQty = (v) => {
            v = Math.max(0, Math.min(maxLoad, parseInt(v) || 0));
            input.value = v; qtyMemory[ing.item] = v;
        };
        row.querySelectorAll('[data-d]').forEach((b) =>
            b.addEventListener('click', () => setQty((parseInt(input.value) || 0) + parseInt(b.dataset.d) * ing.perBatch)));
        input.addEventListener('input', () => { qtyMemory[ing.item] = parseInt(input.value) || 0; });
        input.addEventListener('change', () => setQty(input.value));
        row.querySelector('[data-max]').addEventListener('click', () => setQty(maxLoad));
        row.querySelector('[data-load]').addEventListener('click', () => {
            const amount = parseInt(input.value) || 0;
            if (amount <= 0) return;
            delete qtyMemory[ing.item];
            act('load', { item: ing.item, amount });
        });
        row.querySelector('[data-unload]').addEventListener('click', () => act('unload', { item: ing.item }));

        hopper.appendChild(row);
        if (focused === ing.item) input.focus();
    });
}

function renderStatus(recipe) {
    const pill = $('status-pill');
    const art = $('still-art');
    const map = {
        idle:    ['ui_idle', ''],
        cooking: ['ui_cooking', 'warn'],
        waiting: ['ui_waiting', 'bad'],
        full:    ['ui_full', 'good'],
        nofuel:  ['ui_nofuel', 'bad'],
    };
    const [key, cls] = map[state.status] || map.idle;
    pill.textContent = t(key);
    pill.className = 'pill ' + cls;
    art.classList.toggle('lit', state.status === 'cooking');

    $('queued').textContent = state.queued || 0;

    batchPaused = null;
    if (state.batch && state.batch.running) {
        batchEndsAt = Date.now() + state.batch.remaining * 1000;
        batchTotal = state.batch.total;
    } else {
        batchEndsAt = null;
        if (state.batch) { batchPaused = state.batch; }
    }
    // fuel only burns while a batch is cooking
    if (state.status === 'cooking') { fuelEndsAt = Date.now() + state.fuel * 1000; }
    else { fuelEndsAt = null; fuelStatic = state.fuel; }
    tickBatch();
    renderFuel();

    // tank
    const out = recipe ? recipe.output : null;
    $('out-img').src = out ? img(out.image) : '';
    $('out-img').style.visibility = out ? 'visible' : 'hidden';
    $('out-label').textContent = out ? out.label + (state.quality ? ` · ${t('ui_quality')} ${state.quality}%` : '') : '—';
    const tankPct = Math.min(100, (state.output / state.outputCap) * 100);
    const tank = $('tank-fill');
    tank.style.width = tankPct + '%';
    tank.className = 'fill ' + (tankPct >= 100 ? 'stat-bad' : tankPct >= 75 ? 'stat-warn' : 'stat-good');
    $('tank-text').textContent = `${state.output} / ${state.outputCap}`;

    const btn = $('btn-collect');
    btn.disabled = !state.canUse || state.output <= 0;
    btn.textContent = `${t('ui_collect')}${state.output > 0 ? ` (${state.output})` : ''}`;
    $('btn-pickup').classList.toggle('hidden', !state.isOwner);
    $('btn-pickup').disabled = !(state.hopperEmpty && state.output === 0 && !state.batch);
}

function renderFuel() {
    const list = $('fuel-list');
    // keep focus on an input while refreshing
    const focused = document.activeElement && document.activeElement.dataset ? document.activeElement.dataset.item : null;
    list.innerHTML = '';
    const editable = state.canUse;
    state.fuels.forEach((f) => {
        const room = Math.floor((state.maxFuel - state.fuel) / f.burnTime);
        const maxLoad = Math.max(0, Math.min(room, f.have));
        const key = 'fuel:' + f.item;
        let qty = (qtyMemory[key] !== undefined) ? qtyMemory[key] : Math.min(1, maxLoad);
        qty = Math.max(0, Math.min(qty, maxLoad));
        const row = document.createElement('div');
        row.className = 'row fuel-row';
        row.innerHTML = `
            <div class="badge-icon"><img src="${img(f.image)}" alt=""></div>
            <div class="row-main">
                <div class="row-title">${esc(f.label)}</div>
                <div class="row-desc">${t('ui_burns')} ${fmt(f.burnTime)} ${t('ui_each')} · ${t('ui_have')} ${f.have}</div>
            </div>
            <div class="qty">
                <button data-d="-1">−</button>
                <input type="number" min="0" max="${maxLoad}" value="${qty}" data-item="${esc(key)}">
                <button data-d="1">+</button>
            </div>
            <button class="wood-btn small muted" data-max>${t('ui_load_all')}</button>
            <button class="wood-btn small" data-add ${!editable || maxLoad <= 0 ? 'disabled' : ''}>${t('ui_add')}</button>`;
        const input = row.querySelector('input');
        const setQty = (v) => { v = Math.max(0, Math.min(maxLoad, parseInt(v) || 0)); input.value = v; qtyMemory[key] = v; };
        row.querySelectorAll('[data-d]').forEach((b) => b.addEventListener('click', () => setQty((parseInt(input.value) || 0) + parseInt(b.dataset.d))));
        input.addEventListener('input', () => { qtyMemory[key] = parseInt(input.value) || 0; });
        input.addEventListener('change', () => setQty(input.value));
        row.querySelector('[data-max]').addEventListener('click', () => setQty(maxLoad));
        row.querySelector('[data-add]').addEventListener('click', () => {
            const amount = parseInt(input.value) || 0;
            if (amount <= 0) return;
            delete qtyMemory[key];
            act('loadFuel', { item: f.item, amount });
        });
        list.appendChild(row);
        if (focused === key) input.focus();
    });
}

function tickFuel() {
    const secs = fuelEndsAt ? Math.max(0, (fuelEndsAt - Date.now()) / 1000) : fuelStatic;
    $('fuel-time').textContent = fmt(secs);
    const pct = state && state.maxFuel ? Math.min(100, (secs / state.maxFuel) * 100) : 0;
    const fill = $('fuel-fill');
    fill.style.width = pct + '%';
    fill.className = 'fill ' + (pct < 15 ? 'stat-bad' : pct < 40 ? 'stat-warn' : 'stat-good');
}

function tickBatch() {
    tickFuel();
    const fill = $('batch-fill');
    if (!batchEndsAt) {
        if (batchPaused) {
            $('batch-time').textContent = `${t('ui_paused')} ${fmt(batchPaused.remaining)}`;
            fill.style.width = (1 - batchPaused.remaining / batchPaused.total) * 100 + '%';
        } else {
            $('batch-time').textContent = '--:--';
            fill.style.width = '0%';
        }
        return;
    }
    const remaining = Math.max(0, (batchEndsAt - Date.now()) / 1000);
    $('batch-time').textContent = fmt(remaining);
    fill.style.width = (batchTotal > 0 ? (1 - remaining / batchTotal) * 100 : 0) + '%';
}

/* ---------------- open / close ---------------- */
function open(data) {
    try {
        state = data.state;
        T = data.locale || {};
        imagePath = data.imagePath || '';
        applyLocale();
        app.classList.remove('hidden');
        render();
        clearInterval(tickTimer);
        tickTimer = setInterval(tickBatch, 1000);
        post('opened');
    } catch (err) {
        console.error(err);
        app.classList.add('hidden');
        state = null;
        post('uiError', { msg: String(err && err.stack || err) });
    }
}

function close() {
    app.classList.add('hidden');
    clearInterval(tickTimer);
    state = null;
    batchEndsAt = null;
}

const board = $('board');

function openBoardUi(d) {
    T = d.locale || {};
    applyLocale();
    const data = d.data || {};
    const rows = data.rows || [];
    const me = data.me || { level: 1, xp: 0 };
    $('board-me').textContent = `${t('ui_level')} ${me.level} · ${me.xp} ${t('ui_xp')}`;
    const list = $('board-list');
    list.innerHTML = rows.length ? '' : `<div class="hint">${esc(t('lb_empty'))}</div>`;
    rows.forEach((r, i) => {
        const row = document.createElement('div');
        row.className = 'row board-row' + (r.me ? ' me' : '');
        row.innerHTML = `
            <div class="rank">${i + 1}</div>
            <div class="row-main"><div class="row-title">${esc(r.name || '—')}</div></div>
            <span class="pill">${esc(t('lb_level'))} ${r.level}</span>
            <span class="pill">${r.xp} ${esc(t('ui_xp'))}</span>`;
        list.appendChild(row);
    });
    board.classList.remove('hidden');
}

window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'board') openBoardUi(d);
    else if (d.action === 'closeBoard') board.classList.add('hidden');
    else if (d.action === 'open') open(d);
    else if (d.action === 'update' && state) { try { state = d.state; render(); } catch (err) { console.error(err); post('uiError', { msg: String(err && err.stack || err) }); } }
    else if (d.action === 'close') close();
});

$('btn-close').addEventListener('click', () => post('close'));
$('board-close').addEventListener('click', () => post('closeBoard'));
$('btn-back').addEventListener('click', () => act('clearRecipe'));
$('btn-change').addEventListener('click', () => act('clearRecipe'));
$('btn-collect').addEventListener('click', () => act('collect'));
$('btn-pickup').addEventListener('click', () => act('pickup'));

document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    if (!board.classList.contains('hidden')) post('closeBoard');
    else if (state) post('close');
});
