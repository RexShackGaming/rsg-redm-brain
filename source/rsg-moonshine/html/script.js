const app = document.getElementById('app');
const $ = (id) => document.getElementById(id);

let state = null;
let T = {};
let imagePath = '';
let batchEndsAt = null;  // local ms timestamp
let batchTotal = 0;
let cutKey = 'normal';   // chosen cut for bottling
let fermentEndsAt = null;
let fermentTotal = 0;
let batchPaused = null;  // {remaining,total} when the fire is out mid batch
let tickTimer = null;
let fuelEndsAt = null;  // local ms timestamp while burning
let fuelStatic = 0;     // seconds when not burning
const qtyMemory = {};    // item -> last typed amount

const t = (k, fb) => T[k] || fb || k;
const resName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-moonshine';

function post(endpoint, data = {}) {
    return fetch(`https://${resName}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).catch(() => {});
}
const act = (action, data = {}) => post('action', { action, data });

function fmt(sec) {
    sec = Math.max(0, Math.floor(sec));
    const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60;
    const mm = String(m).padStart(2, '0'), ss = String(s).padStart(2, '0');
    return h > 0 ? `${h}:${mm}:${ss}` : `${mm}:${ss}`;
}

function img(name) { return imagePath + name; }

function applyLocale() {
    document.querySelectorAll('[data-t]').forEach((el) => {
        const k = el.getAttribute('data-t');
        if (T[k]) el.textContent = T[k];
    });
    document.querySelectorAll('[data-t-placeholder]').forEach((el) => {
        const k = el.getAttribute('data-t-placeholder');
        if (T[k]) el.placeholder = T[k];
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
    const barrel = state.kind === 'barrel';
    app.classList.toggle('barrel', barrel);
    $('title-h').textContent = t(barrel ? 'ui_barrel_title' : 'ui_title');
    $('title-sub').textContent = barrel ? t('ui_barrel_subtitle') : t('ui_material_' + (state.material || 'copper'), t('ui_subtitle'));
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
    state.recipes.forEach((r) => {
        const unlocked = state.level >= (r.level || 1);
        const can = editable && unlocked;
        const row = document.createElement('div');
        row.className = 'row' + (can ? ' clickable' : ' disabled');
        const tags = r.ingredients.map((i) => `<span class="pill">${i.perBatch}x ${i.label}</span>`).join('');
        row.innerHTML = `
            <div class="badge-icon"><img src="${img(r.output.image)}" alt=""></div>
            <div class="row-main">
                <div class="row-title">${r.label}</div>
                <div class="row-desc">${t('ui_makes')} ${r.output.amount}x ${r.output.label} · ${t('ui_batch_time')} ${fmt(r.time)}</div>
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
    const iq = $('ra-iq');
    iq.textContent = state.ingQ != null ? `${t('ui_ingredient_quality')}: ${state.ingQ}` : '';
    $('btn-change').disabled = !editable || !(state.hopperEmpty && state.output === 0 && !state.batch && !state.ferment && !state.rerun && !(state.wash > 0));

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
                <div class="row-title">${ing.label}</div>
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
                    <input type="number" min="0" max="${maxLoad}" value="${qty}" data-item="${ing.item}">
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
        brewing: ['ui_brewing', 'warn'],
        waiting: ['ui_waiting', 'bad'],
        full:    ['ui_full', 'good'],
        rerun:   ['ui_rerunning', 'warn'],
        fermenting: ['ui_fermenting', 'warn'],
        nofuel:  ['ui_nofuel', 'bad'],
    };
    const [key, cls] = map[state.status] || map.idle;
    pill.textContent = t(key);
    pill.className = 'pill ' + cls;
    art.classList.toggle('lit', state.status === 'brewing' || state.status === 'rerun');

    $('queued').textContent = state.queued || 0;

    batchPaused = null;
    const work = state.rerun || state.batch;
    $('batch-label').textContent = state.rerun ? t('ui_rerunning') : t('ui_current_batch');
    if (work && work.running) {
        batchEndsAt = Date.now() + work.remaining * 1000;
        batchTotal = work.total;
    } else {
        batchEndsAt = null;
        if (work) { batchPaused = work; }
    }
    // fermentation runs on its own, even with the fire out
    $('ferment-stat').classList.toggle('hidden', !state.ferment);
    fermentEndsAt = state.ferment ? Date.now() + state.ferment.remaining * 1000 : null;
    fermentTotal = state.ferment ? state.ferment.total : 0;
    $('wash').textContent = `${state.wash || 0} / ${state.maxWash || 0}`;
    const envKey = state.weather === 'cold' ? 'ui_weather_cold' : state.weather === 'wet' ? 'ui_weather_wet' : (state.night ? 'ui_night' : null);
    $('env-hint').textContent = envKey ? t(envKey) : '';
    $('env-hint').classList.toggle('hidden', !envKey);
    // fuel only burns while a batch or a second run is cooking
    const burn = state.burnRate || 1; // fuel units burn faster on a hot fire, so show real time
    if (state.status === 'brewing' || state.status === 'rerun') { fuelEndsAt = Date.now() + (state.fuel / burn) * 1000; }
    else { fuelEndsAt = null; fuelStatic = state.fuel / burn; }
    tickBatch();
    renderFuel();

    // tank
    const out = recipe ? recipe.output : null;
    $('out-img').src = out ? img(out.image) : '';
    $('out-img').style.visibility = out ? 'visible' : 'hidden';
    $('out-label').textContent = out ? out.label : '—';
    const tankPct = Math.min(100, (state.output / state.outputCap) * 100);
    const tank = $('tank-fill');
    tank.style.width = tankPct + '%';
    tank.className = 'fill ' + (tankPct >= 100 ? 'stat-bad' : tankPct >= 75 ? 'stat-warn' : 'stat-good');
    $('tank-text').textContent = `${state.output} / ${state.outputCap}`;

    const barrel = state.kind === 'barrel';
    // wash: a barrel hands it out, a still takes it in
    const washBtn = $('btn-wash');
    $('wash-box').classList.toggle('hidden', !recipe);
    if (barrel) {
        washBtn.textContent = `${t('ui_wash_take')} (${state.wash || 0})`;
        washBtn.disabled = !state.canUse || !(state.wash > 0);
        $('wash-hint').textContent = '';
    } else {
        washBtn.textContent = t('ui_wash_load');
        washBtn.disabled = !state.canUse || !recipe || !(state.washHave > 0) || state.wash >= state.maxWash;
        $('wash-hint').textContent = `${t('ui_wash_carried')}: ${state.washHave || 0}`;
    }
    renderHeat();
    renderCare();
    renderCuts();
    renderCask(recipe);
    const canRerun = state.canUse && !state.reran && !state.batch && !state.rerun && state.output >= 2;
    $('rerun-box').classList.toggle('hidden', !(state.canUse && state.output > 0 && !state.reran) && !state.rerun);
    $('btn-rerun').disabled = !canRerun;
    $('proof-wrap').classList.toggle('hidden', !state.proof || (state.output <= 0 && !state.rerun));
    $('proof').textContent = state.proof ? `${state.proof}${state.reran ? ' ✦' : ''}` : '';

    const jugEl = $('jug-count');
    jugEl.textContent = state.jugs;
    jugEl.className = state.jugs > 0 ? '' : 'none';
    const btn = $('btn-collect');
    btn.disabled = !state.canUse || state.output <= 0 || state.jugs <= 0;
    btn.textContent = (state.output > 0 && state.jugs <= 0)
        ? t('ui_need_jugs')
        : `${t('ui_collect')}${state.output > 0 ? ` (${Math.min(state.output, state.jugs)})` : ''}`;
    $('quality-wrap').classList.toggle('hidden', state.quality === undefined || state.quality === null || state.output <= 0);
    $('quality').textContent = state.quality || 0;
    renderAccess();
    renderLabel();
    $('btn-pickup').classList.toggle('hidden', !state.isOwner);
    $('btn-pickup').disabled = !(state.hopperEmpty && state.output === 0 && !state.batch && !state.ferment && !state.rerun && !(state.wash > 0) && !(state.cask && state.cask.volume > 0));
}

function renderCare() {
    const ws = $('water-stat');
    ws.classList.toggle('hidden', state.water == null);
    if (state.water != null) {
        $('water-time').textContent = fmt(state.water);
        const pct = Math.min(100, state.water / state.maxWater * 100);
        const f = $('water-fill');
        f.style.width = pct + '%';
        f.className = 'fill ' + (state.water <= 0 ? 'stat-bad' : pct < 25 ? 'stat-warn' : 'stat-good');
        const room = Math.floor((state.maxWater - state.water) / state.waterStep);
        const b = $('btn-water');
        b.textContent = `${t('ui_add_water')} (${state.waterHave})`;
        b.disabled = !state.canUse || room <= 0 || state.waterHave <= 0;
        $('dry-warn').classList.toggle('hidden', !state.dry);
    }
    const wr = $('wear-stat');
    wr.classList.toggle('hidden', state.wear == null);
    if (state.wear != null) {
        $('wear-val').textContent = state.wear + '%';
        const f = $('wear-fill');
        f.style.width = state.wear + '%';
        f.className = 'fill ' + (state.wear >= 60 ? 'stat-bad' : state.wear >= 30 ? 'stat-warn' : 'stat-good');
        const b = $('btn-clean');
        b.textContent = `${t('ui_clean')} (${state.cleanHave})`;
        b.disabled = !state.canUse || state.wear <= 0 || state.cleanHave <= 0 || !!state.batch || !!state.rerun;
    }
}

function renderHeat() {
    const seg = $('heat-seg');
    seg.innerHTML = '';
    (state.heats || []).forEach((h) => {
        const b = document.createElement('button');
        b.className = 'wood-btn small muted' + (h.key === state.heat ? ' active' : '');
        b.textContent = t('ui_heat_' + h.key);
        b.disabled = !state.canUse;
        b.addEventListener('click', () => { if (h.key !== state.heat) act('setHeat', { heat: h.key }); });
        seg.appendChild(b);
    });
}

function renderCuts() {
    const cuts = state.cuts || [];
    if (!cuts.find((c) => c.key === cutKey)) cutKey = (cuts.find((c) => c.key === 'normal') || cuts[0] || {}).key;
    const seg = $('cut-seg');
    seg.innerHTML = '';
    cuts.forEach((c) => {
        const b = document.createElement('button');
        b.className = 'wood-btn small muted' + (c.key === cutKey ? ' active' : '');
        b.textContent = t('ui_cut_' + c.key);
        b.addEventListener('click', () => { cutKey = c.key; renderCuts(); });
        seg.appendChild(b);
    });
    const cur = cuts.find((c) => c.key === cutKey);
    const riskKey = ['ui_risk_none', 'ui_risk_low', 'ui_risk_med', 'ui_risk_high'];
    $('cut-info').textContent = cur
        ? `${t('ui_yield')} ${cur.yield}% · ${t('ui_quality')} ${cur.quality >= 0 ? '+' : ''}${cur.quality} · ${t(riskKey[cur.risk] || riskKey[0])}`
        : '';
    const sb = $('btn-sample');
    sb.classList.toggle('hidden', !state.taste);
    sb.disabled = !state.canUse || state.output < 2;
    const si = $('sample-info');
    const sm = state.sample && state.sample[cutKey] !== undefined ? state.sample[cutKey] : null; // true = foul
    si.textContent = sm === null ? '' : t(sm ? 'ui_sample_foul' : 'ui_sample_safe');
    si.className = 'hint small' + (sm === null ? '' : (sm ? ' foul' : ' safe'));
}

function renderCask(recipe) {
    const c = state.cask;
    $('cask-box').classList.toggle('hidden', !c || !recipe && !c.installed);
    if (!c) return;
    const body = $('cask-body');
    body.innerHTML = '';
    if (!c.installed) {
        body.innerHTML = `<div class="meta"><span>${t('ui_cask_none')}</span><span>${c.item}: <b>${c.have}</b></span></div>
            <div class="cask-actions"><button class="wood-btn small" data-install ${!state.canUse || c.have <= 0 ? 'disabled' : ''}>${t('ui_cask_install')}</button></div>`;
        body.querySelector('[data-install]').addEventListener('click', () => act('installCask'));
        return;
    }
    const info = c.volume > 0
        ? `<div class="meta"><span>${c.recipe || ''}</span><span>${t('ui_volume')} <b>${c.volume} / ${c.capacity}</b></span></div>
           <div class="meta"><span>${c.quality != null ? `${t('ui_quality')} <b>${c.quality}</b>` : ''}</span><span>${c.proof ? `${t('ui_proof')} <b>${c.proof}</b>` : ''}</span></div>
           <div class="meta"><span>${c.ageing ? `${t('ui_cask_ageing')} <b>${c.steps}</b>` : ''}</span><span>${c.ageing && c.nextStep ? `${t('ui_cask_next')} <b>${fmt(c.nextStep)}</b>` : ''}</span></div>`
        : `<div class="hint small">${t('ui_cask_empty')}</div>`;
    body.innerHTML = `${info}
        <div class="cask-actions">
            <button class="wood-btn small" data-age ${!state.canUse || c.volume > 0 || state.output <= 0 ? 'disabled' : ''}>${t('ui_cask_age')}</button>
            <button class="wood-btn small" data-take ${!state.canUse || c.volume <= 0 || state.jugs <= 0 ? 'disabled' : ''}>${t('ui_cask_collect')}</button>
        </div>
        <div class="hint small">${t('ui_cask_hint')}</div>`;
    body.querySelector('[data-age]').addEventListener('click', () => act('age'));
    body.querySelector('[data-take]').addEventListener('click', () => act('collectCask', { cut: cutKey }));
}

function renderLabel() {
    const show = !!(state.labelMax && state.canUse && state.recipe);
    $('label-box').classList.toggle('hidden', !show);
    if (!show) return;
    const input = $('label-input');
    input.maxLength = state.labelMax;
    if (document.activeElement !== input) input.value = state.label || ''; // never overwrite while typing
}

function renderAccess() {
    const show = !!(state.isOwner && state.ownerOnly);
    $('access').classList.toggle('hidden', !show);
    if (!show) return;
    const list = $('access-list');
    list.innerHTML = '';
    const trusted = state.trusted || [];
    if (trusted.length === 0) {
        const none = document.createElement('div');
        none.className = 'hint';
        none.textContent = t('ui_trusted_none');
        list.appendChild(none);
    }
    trusted.forEach((p) => {
        const row = document.createElement('div');
        row.className = 'row access-row';
        const main = document.createElement('div');
        main.className = 'row-main';
        const title = document.createElement('div');
        title.className = 'row-title';
        title.textContent = p.name; // textContent: names come from player data
        main.appendChild(title);
        const btn = document.createElement('button');
        btn.className = 'wood-btn small muted';
        btn.textContent = t('ui_remove');
        btn.addEventListener('click', () => act('untrust', { cid: p.cid }));
        row.appendChild(main);
        row.appendChild(btn);
        list.appendChild(row);
    });
    $('btn-trust').disabled = trusted.length >= (state.trustedMax || 0);
}

function renderFuel() {
    const list = $('fuel-list');
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
                <div class="row-title">${f.label}</div>
                <div class="row-desc">${t('ui_burns')} ${fmt(f.burnTime)} ${t('ui_each')} · ${t('ui_have')} ${f.have}</div>
            </div>
            <div class="qty">
                <button data-d="-1">−</button>
                <input type="number" min="0" max="${maxLoad}" value="${qty}" data-item="${key}">
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
    });
}

function tickFuel() {
    const secs = fuelEndsAt ? Math.max(0, (fuelEndsAt - Date.now()) / 1000) : fuelStatic;
    $('fuel-time').textContent = fmt(secs);
    const pct = state && state.maxFuel ? Math.min(100, (secs * (state.burnRate || 1) / state.maxFuel) * 100) : 0;
    const fill = $('fuel-fill');
    fill.style.width = pct + '%';
    fill.className = 'fill ' + (secs <= 0 ? 'stat-bad' : pct < 15 ? 'stat-bad' : pct < 40 ? 'stat-warn' : 'stat-good');
}

function tickBatch() {
    tickFuel();
    if (fermentEndsAt) {
        const left = Math.max(0, (fermentEndsAt - Date.now()) / 1000);
        $('ferment-time').textContent = fmt(left);
        $('ferment-fill').style.width = (fermentTotal > 0 ? (1 - left / fermentTotal) * 100 : 0) + '%';
    }
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
    fermentEndsAt = null;
}

window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'open') open(d);
    else if (d.action === 'update' && state) { try { state = d.state; render(); } catch (err) { console.error(err); post('uiError', { msg: String(err && err.stack || err) }); } }
    else if (d.action === 'close') close();
});

$('btn-close').addEventListener('click', () => post('close'));
$('btn-back').addEventListener('click', () => act('clearRecipe'));
$('btn-change').addEventListener('click', () => act('clearRecipe'));
$('btn-collect').addEventListener('click', () => act('collect', { cut: cutKey }));
$('btn-wash').addEventListener('click', () => act(state && state.kind === 'barrel' ? 'collectWash' : 'loadWash'));
$('btn-water').addEventListener('click', () => act('addWater', { amount: 1 }));
$('btn-clean').addEventListener('click', () => act('clean'));
$('btn-sample').addEventListener('click', () => act('sample', { cut: cutKey }));
$('btn-rerun').addEventListener('click', () => act('rerun'));
$('btn-trust').addEventListener('click', () => act('trust'));
$('btn-label').addEventListener('click', () => act('setLabel', { label: $('label-input').value }));
$('label-input').addEventListener('keydown', (e) => { if (e.key === 'Enter') act('setLabel', { label: $('label-input').value }); });
$('btn-pickup').addEventListener('click', () => act('pickup'));

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && state) post('close');
});
