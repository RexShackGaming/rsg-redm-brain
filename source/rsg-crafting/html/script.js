const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-crafting';

const FAV_KEY = 'rsg-crafting:favs';

const state = {
    L: {}, imagePath: '', maxBatch: 10,
    xp: 0, nextUnlock: null, recipes: [],
    category: 'all', search: '', selected: null, qty: 1,
    crafting: false, progressTimer: null, progressInfo: null,
    queueEnabled: false, queueMax: 0, queue: [],
    favs: new Set(),
};

const $ = (id) => document.getElementById(id);

function fmt(str, ...args) {
    let i = 0;
    return String(str || '').replace(/%s/g, () => (args[i++] ?? ''));
}

function esc(s) {
    return String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function fmtTime(ms) {
    const total = Math.round(ms / 1000);
    if (total < 60) return fmt(state.L.seconds, total);
    return fmt(state.L.minutes_seconds, Math.floor(total / 60), total % 60);
}

function post(name, data = {}) {
    return fetch(`https://${RES}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).then((r) => r.json()).catch(() => ({}));
}

function img(name) {
    return name ? state.imagePath + name : '';
}

/* ---------- favourites (kept per player in the browser) ---------- */
function loadFavs() {
    try {
        const list = JSON.parse(localStorage.getItem(FAV_KEY) || '[]');
        state.favs = new Set(Array.isArray(list) ? list.filter((k) => typeof k === 'string') : []);
    } catch (_) { state.favs = new Set(); }
}

function saveFavs() {
    try { localStorage.setItem(FAV_KEY, JSON.stringify([...state.favs])); } catch (_) {}
}

/* ---------- render ---------- */
function renderHeader() {
    $('title').textContent = state.L.menu_title;
    $('reset-pos-btn').title = state.L.ui_reset_pos || '';
    $('close-btn').title = state.L.ui_close || '';
    $('xp-text').textContent = fmt(state.L.menu_current_xp, state.xp);
    $('search').placeholder = state.L.ui_search || '';
    if (state.nextUnlock) {
        // progress from the highest unlocked threshold to the next unlock
        const unlocked = state.recipes.filter((r) => !r.locked).map((r) => r.requiredxp);
        const base = unlocked.length ? Math.max(...unlocked) : 0;
        const pct = Math.min(100, ((state.xp - base) / Math.max(1, state.nextUnlock - base)) * 100);
        $('xp-bar').style.width = `${Math.max(0, pct)}%`;
        $('xp-next').textContent = fmt(state.L.ui_next_unlock, state.nextUnlock);
    } else {
        $('xp-bar').style.width = '100%';
        $('xp-next').textContent = '';
    }
}

function renderTabs() {
    const cats = new Map(); // category key -> { label, image }
    state.recipes.forEach((r) => {
        if (!cats.has(r.category)) cats.set(r.category, { label: r.categoryLabel || r.category, image: r.categoryImage });
    });
    const tabs = [{ key: 'all', label: state.L.ui_all }];
    if (state.favs.size > 0) tabs.push({ key: '__fav', label: state.L.ui_favourites });
    cats.forEach((v, key) => tabs.push({ key, label: v.label, image: v.image }));
    if (!tabs.some((t) => t.key === state.category)) state.category = 'all';

    $('tabs').innerHTML = tabs.map((t) =>
        `<div class="tab ${t.key === state.category ? 'active' : ''}" data-cat="${esc(t.key)}">${
            t.image ? `<img class="tab-icon" src="${esc(img(t.image))}" onerror="this.style.display='none'">` : ''
        }<span>${esc(t.label)}</span></div>`
    ).join('');
    $('tabs').querySelectorAll('.tab').forEach((t) => t.addEventListener('click', () => {
        state.category = t.dataset.cat;
        renderTabs();
        renderList();
    }));
}

function visibleRecipes() {
    const needle = state.search.trim().toLowerCase();
    return state.recipes.filter((r) => {
        if (state.category === '__fav' && !state.favs.has(r.key)) return false;
        if (state.category !== 'all' && state.category !== '__fav' && r.category !== state.category) return false;
        return !needle || String(r.label).toLowerCase().includes(needle);
    });
}

function renderList() {
    const list = visibleRecipes();
    if (list.length === 0) {
        $('recipe-list').innerHTML = `<div class="list-empty">${esc(state.L.ui_no_results)}</div>`;
        return;
    }
    $('recipe-list').innerHTML = list.map((r) => {
        let pill;
        if (r.blueprintLocked) pill = `<span class="pill">${esc(state.L.ui_blueprint)}</span>`;
        else if (r.locked) pill = `<span class="pill">${esc(fmt(state.L.ui_requires, r.requiredxp))}</span>`;
        else if (r.maxCraftable > 0) pill = `<span class="pill ok">${esc(fmt(state.L.ui_count, r.maxCraftable))}</span>`;
        else pill = `<span class="pill">${esc(fmt(state.L.ui_count, 0))}</span>`;
        const sub = r.locked ? state.L.ui_locked : fmt(state.L.ui_makes, r.giveamount);
        return `<div class="row ${r.locked ? 'locked' : ''} ${state.selected === r.id ? 'selected' : ''}" data-id="${r.id}">
            <div class="badge-icon"><img src="${esc(img(r.image))}" onerror="this.style.display='none'"></div>
            <div class="row-text">
                <div class="row-title">${esc(r.label)}</div>
                <div class="row-sub">${esc(r.station ? `${sub} · ${r.station}` : sub)}</div>
            </div>
            ${pill}
            <button class="star ${state.favs.has(r.key) ? 'on' : ''}" data-key="${esc(r.key)}" title="${esc(state.L.ui_favourites)}"></button>
        </div>`;
    }).join('');
    $('recipe-list').querySelectorAll('.row').forEach((row) => row.addEventListener('click', () => {
        if (state.crafting && !state.queueEnabled) return;
        state.selected = Number(row.dataset.id);
        state.qty = 1;
        renderList();
        renderDetail();
    }));
    $('recipe-list').querySelectorAll('.star').forEach((star) => star.addEventListener('click', (e) => {
        e.stopPropagation();
        const key = star.dataset.key;
        if (state.favs.has(key)) state.favs.delete(key); else state.favs.add(key);
        saveFavs();
        renderTabs();
        renderList();
    }));
}

function current() {
    return state.recipes.find((r) => r.id === state.selected);
}

function maxQtyFor(r) {
    return Math.max(1, Math.min(state.maxBatch, r.maxCraftable || 1));
}

function metaCell(label, value, tone) {
    return `<div class="meta"><span>${esc(label)}</span><b class="${tone || ''}">${esc(value)}</b></div>`;
}

function renderDetail() {
    const r = current();
    $('detail-empty').textContent = state.L.ui_select;
    if (!r) {
        $('detail-empty').classList.remove('hidden');
        $('detail-content').classList.add('hidden');
        return;
    }
    $('detail-empty').classList.add('hidden');
    $('detail-content').classList.remove('hidden');

    const maxQty = maxQtyFor(r);
    state.qty = Math.min(Math.max(1, state.qty), maxQty);
    const q = state.qty;

    const dImg = $('d-img');
    dImg.style.display = '';
    dImg.src = img(r.image);
    dImg.onerror = () => { dImg.style.display = 'none'; };
    $('d-label').textContent = r.label;
    $('d-desc').textContent = r.blueprintLocked ? state.L.ui_blueprint
        : (r.locked ? fmt(state.L.ui_requires, r.requiredxp) : (r.description || ''));

    $('m-makes-l').textContent = fmt(state.L.ui_makes, '').trim();
    $('m-makes').textContent = r.giveamount * q;
    $('m-time-l').textContent = state.L.ui_time;
    $('m-time').textContent = fmtTime(r.crafttime * q);
    $('m-xp-l').textContent = state.L.ui_xp_label;
    $('m-xp').textContent = fmt(state.L.ui_xp, r.xpreward * q);

    // fail chance, quality and station
    const extra = [];
    if (r.failchance) extra.push(metaCell(state.L.ui_fail_chance, `${r.failchance}%`, r.failchance >= 25 ? 'bad' : 'warn'));
    if (r.quality) extra.push(metaCell(state.L.ui_quality, `~${r.quality}%`, ''));
    if (r.station) extra.push(metaCell(state.L.ui_station, r.station, r.stationOk ? 'ok' : 'bad'));
    $('extra-meta').innerHTML = extra.join('');
    $('extra-meta').classList.toggle('hidden', extra.length === 0);

    $('ing-label').textContent = state.L.ui_ingredients;
    $('ingredients').innerHTML = r.ingredients.map((ing) => {
        const need = ing.amount * q;
        const ok = ing.have >= need;
        return `<div class="ing">
            <div class="badge-icon"><img src="${esc(img(ing.image))}" onerror="this.style.display='none'"></div>
            <span class="ing-name">${esc(ing.label)}</span>
            <span class="ing-count ${ok ? 'ok' : 'bad'}">${esc(fmt(state.L.ui_have_need, ing.have, need))}</span>
        </div>`;
    }).join('');

    const tools = r.tools || [];
    const toolsOk = tools.every((t) => t.have >= t.amount);
    $('tools-wrap').classList.toggle('hidden', tools.length === 0);
    $('tools-label').textContent = state.L.ui_required_tools;
    $('tools').innerHTML = tools.map((t) => {
        const ok = t.have >= t.amount;
        return `<div class="ing">
            <div class="badge-icon"><img src="${esc(img(t.image))}" onerror="this.style.display='none'"></div>
            <span class="ing-name">${esc(t.label)}</span>
            <span class="ing-count ${ok ? 'ok' : 'bad'}">${esc(fmt(state.L.ui_have_need, Math.min(t.have, t.amount), t.amount))}</span>
        </div>`;
    }).join('');

    $('qty-label').textContent = state.L.ui_quantity;
    $('qty-val').textContent = q;

    const queueing = state.crafting && state.queueEnabled;
    const queueFull = queueing && state.queue.length >= state.queueMax;
    const stationBlocked = r.station && !r.stationOk;
    const canCraft = !r.locked && r.maxCraftable >= q && !stationBlocked && !queueFull;
    const btn = $('craft-btn');
    btn.disabled = !canCraft || (state.crafting && !state.queueEnabled);

    let text;
    if (r.blueprintLocked) text = state.L.ui_blueprint;
    else if (r.locked) text = state.L.ui_locked;
    else if (!toolsOk) text = state.L.ui_missing_tools;
    else if (stationBlocked) text = fmt(state.L.ui_not_at_station, r.station);
    else if (r.maxCraftable < 1) text = state.L.ui_missing;
    else text = fmt(queueing ? state.L.ui_add_queue : state.L.ui_craft, q);
    btn.textContent = text;
    btn.classList.toggle('hidden', state.crafting && !state.queueEnabled);

    $('stop-btn').textContent = state.L.ui_stop;
    $('stop-btn').classList.toggle('hidden', !state.crafting);
    const locked = state.crafting && !state.queueEnabled;
    $('qty-minus').disabled = locked || q <= 1;
    $('qty-plus').disabled = locked || q >= maxQty;
    $('qty-max').textContent = state.L.ui_max;
    $('qty-max').disabled = locked || q >= maxQty;
}

function renderQueue() {
    const wrap = $('queue-wrap');
    wrap.classList.toggle('hidden', state.queue.length === 0);
    $('queue-label').textContent = `${state.L.ui_queue || ''} (${state.queue.length}/${state.queueMax})`;
    $('queue-list').innerHTML = state.queue.map((q, i) => `<div class="queue-item">
        <span class="q-pos">${i + 1}</span>
        <span class="q-name">${esc(q.label)}</span>
        <span class="q-qty">${esc(fmt(state.L.ui_count, q.qty))}</span>
        <button class="circle-btn small" data-i="${i + 1}" title="${esc(state.L.ui_remove)}">&#10005;</button>
    </div>`).join('');
    $('queue-list').querySelectorAll('button').forEach((b) => b.addEventListener('click', () => {
        post('queueRemove', { index: Number(b.dataset.i) });
    }));
}

function renderAll() {
    renderHeader();
    renderTabs();
    renderList();
    renderDetail();
    renderQueue();
}

function setStatus(msg, ok) {
    const s = $('status');
    s.textContent = msg || '';
    s.className = 'status' + (msg ? (ok ? ' ok' : ' bad') : '');
}

/* ---------- crafting progress ---------- */
function startProgress(ms, label, qty, elapsed = 0) {
    state.crafting = true;
    state.progressInfo = { label, qty };
    $('progress-wrap').classList.remove('hidden');
    $('progress-label').textContent = fmt(state.L.ui_crafting, fmt(state.L.amount_item, qty, label));
    const bar = $('progress-bar');
    const start = Date.now() - elapsed;
    bar.style.width = '0%';
    clearInterval(state.progressTimer);
    state.progressTimer = setInterval(() => {
        const pct = Math.min(100, ((Date.now() - start) / ms) * 100);
        bar.style.width = `${pct}%`;
        if (pct >= 100) clearInterval(state.progressTimer);
    }, 50);
    renderDetail();
}

function stopProgress() {
    state.crafting = false;
    clearInterval(state.progressTimer);
    $('progress-wrap').classList.add('hidden');
    $('progress-bar').style.width = '0%';
    renderDetail();
}

/* ---------- events ---------- */
$('close-btn').addEventListener('click', () => post('close'));

$('search').addEventListener('input', (e) => {
    state.search = e.target.value;
    renderList();
});

$('qty-minus').addEventListener('click', () => {
    if (state.crafting && !state.queueEnabled) return;
    state.qty = Math.max(1, state.qty - 1);
    renderDetail();
});

$('qty-plus').addEventListener('click', () => {
    const r = current();
    if (!r || (state.crafting && !state.queueEnabled)) return;
    state.qty += 1; // clamped in renderDetail
    renderDetail();
});

$('qty-max').addEventListener('click', () => {
    const r = current();
    if (!r || (state.crafting && !state.queueEnabled)) return;
    state.qty = maxQtyFor(r);
    renderDetail();
});

$('craft-btn').addEventListener('click', async () => {
    const r = current();
    if (!r || r.locked || (state.crafting && !state.queueEnabled)) return;
    setStatus('');
    $('craft-btn').disabled = true;
    const res = await post('craft', { id: r.id, qty: state.qty, label: r.label });
    if (res && res.ok && res.queued) {
        setStatus(state.L.ui_queue_added, true);
        renderDetail();
    } else if (res && res.ok) {
        startProgress(res.crafttime, res.label, res.qty);
    } else {
        setStatus(res && res.error, false);
        renderDetail();
    }
});

$('stop-btn').addEventListener('click', () => post('cancel'));

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !$('app').classList.contains('hidden')) post('close');
});

window.addEventListener('message', (e) => {
    const d = e.data || {};
    switch (d.action) {
        case 'open':
            state.L = d.locale || {};
            state.imagePath = d.imagePath || '';
            state.maxBatch = d.maxBatch || 10;
            state.queueEnabled = !!d.queueEnabled;
            state.queueMax = d.queueMax || 0;
            state.queue = d.queue || [];
            state.xp = d.xp || 0;
            state.nextUnlock = d.nextUnlock || null;
            state.recipes = d.recipes || [];
            state.category = 'all';
            state.search = '';
            $('search').value = '';
            state.selected = null;
            state.qty = 1;
            state.crafting = false;
            loadFavs();
            setStatus('');
            $('progress-wrap').classList.add('hidden');
            $('app').classList.remove('hidden');
            applyPos();
            renderAll();
            if (d.active) {
                state.selected = d.active.id;
                state.category = 'all';
                renderAll();
                startProgress(d.active.duration, d.active.label, d.active.qty, d.active.elapsed);
            }
            break;
        case 'refresh':
            state.xp = d.xp || 0;
            state.nextUnlock = d.nextUnlock || null;
            state.recipes = d.recipes || [];
            renderAll();
            break;
        case 'queue':
            state.queue = d.queue || [];
            renderQueue();
            renderDetail();
            break;
        case 'started':
            // the next craft in the queue began
            state.selected = d.id;
            state.qty = 1;
            setStatus('');
            renderList();
            startProgress(d.crafttime, d.label, d.qty);
            break;
        case 'progress':
            // a helper joined: the total time changed
            if (state.progressInfo) startProgress(d.duration, state.progressInfo.label, state.progressInfo.qty, d.elapsed);
            break;
        case 'finished':
            stopProgress();
            setStatus(d.message, d.ok);
            break;
        case 'cancelled':
            stopProgress();
            setStatus(state.L.ui_cancelled, false);
            break;
        case 'close':
            clearInterval(state.progressTimer);
            state.crafting = false;
            $('app').classList.add('hidden');
            break;
    }
});

/* ---------- draggable panel (position saved per player) ---------- */
const POS_KEY = 'rsg-crafting:panelPos';
const panel = document.querySelector('.panel');
const header = document.querySelector('.panel-header');
const pos = { x: 0, y: 0 };

function clampPos() {
    // keep the whole panel on screen (offset is relative to centred position)
    const maxX = Math.max(0, (window.innerWidth - panel.offsetWidth) / 2);
    const maxY = Math.max(0, (window.innerHeight - panel.offsetHeight) / 2);
    pos.x = Math.min(maxX, Math.max(-maxX, pos.x));
    pos.y = Math.min(maxY, Math.max(-maxY, pos.y));
}
function applyPos() {
    clampPos();
    panel.style.transform = `translate(${pos.x}px, ${pos.y}px)`;
}
function savePos() {
    try { localStorage.setItem(POS_KEY, JSON.stringify(pos)); } catch (_) {}
}
function loadPos() {
    try {
        const p = JSON.parse(localStorage.getItem(POS_KEY) || 'null');
        if (p && Number.isFinite(p.x) && Number.isFinite(p.y)) { pos.x = p.x; pos.y = p.y; }
    } catch (_) {}
}
function resetPos() {
    pos.x = 0; pos.y = 0;
    applyPos();
    savePos();
}

let drag = null;
header.addEventListener('mousedown', (e) => {
    if (e.button !== 0 || e.target.closest('button')) return;
    drag = { sx: e.clientX, sy: e.clientY, ox: pos.x, oy: pos.y };
    panel.classList.add('dragging');
    e.preventDefault();
});
document.addEventListener('mousemove', (e) => {
    if (!drag) return;
    pos.x = drag.ox + (e.clientX - drag.sx);
    pos.y = drag.oy + (e.clientY - drag.sy);
    applyPos();
});
document.addEventListener('mouseup', () => {
    if (!drag) return;
    drag = null;
    panel.classList.remove('dragging');
    savePos();
});
header.addEventListener('dblclick', (e) => { if (!e.target.closest('button')) resetPos(); });
$('reset-pos-btn').addEventListener('click', resetPos);
window.addEventListener('resize', applyPos);

loadPos();
applyPos();
