const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'rsg-boats';
const $ = (id) => document.getElementById(id);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

async function post(name, data = {}) {
    try {
        const r = await fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) });
        return await r.json();
    } catch (e) { return false; }
}

let L = {};
const t = (k, ...a) => { let s = L[k] || k; a.forEach((v) => { s = s.replace('%s', v); }); return s; };
function applyLocales(loc) {
    if (!loc) return;
    L = loc;
    document.querySelectorAll('[data-i18n]').forEach((el) => { if (L[el.dataset.i18n]) el.textContent = L[el.dataset.i18n]; });
    document.querySelectorAll('[data-i18n-ph]').forEach((el) => { if (L[el.dataset.i18nPh]) el.placeholder = L[el.dataset.i18nPh]; });
}

let shopData = null;
let adminData = null;
let busy = false;

/* ---------- dropdown helper (no native select) ---------- */
function setupDd(el, options, value, onChange) {
    const valEl = el.querySelector('.dd-value');
    const menu = el.querySelector('.dd-menu');
    const render = () => {
        const cur = options.find((o) => o.value === el.dataset.value);
        valEl.textContent = cur ? cur.label : '—';
        menu.innerHTML = options.map((o) => `<div class="dd-opt ${o.value === el.dataset.value ? 'sel' : ''}" data-v="${esc(o.value)}">${esc(o.label)}</div>`).join('');
    };
    el.dataset.value = value ?? (options[0] && options[0].value) ?? '';
    render();
    el.onmousedown = (e) => {
        const opt = e.target.closest('.dd-opt');
        if (opt) {
            e.preventDefault();
            el.dataset.value = opt.dataset.v;
            el.classList.remove('open');
            render();
            if (onChange) onChange(el.dataset.value);
            return;
        }
        document.querySelectorAll('.dd.open').forEach((d) => d !== el && d.classList.remove('open'));
        el.classList.toggle('open');
    };
}
document.addEventListener('mousedown', (e) => { if (!e.target.closest('.dd')) document.querySelectorAll('.dd.open').forEach((d) => d.classList.remove('open')); });
const closeDds = () => document.querySelectorAll('.dd.open').forEach((d) => d.classList.remove('open'));

/* ---------- modal ---------- */
function confirmModal(title, text, withInput) {
    return new Promise((resolve) => {
        $('modal-title').textContent = title;
        $('modal-text').textContent = text;
        $('modal-input').classList.toggle('hidden', !withInput);
        $('modal-input').value = '';
        $('modal').classList.remove('hidden');
        if (withInput) setTimeout(() => $('modal-input').focus(), 0);
        const done = (v) => { $('modal').classList.add('hidden'); $('modal-yes').onclick = $('modal-no').onclick = null; resolve(v); };
        $('modal-yes').onclick = () => {
            if (!withInput) return done(true);
            const n = Number($('modal-input').value);
            if (Number.isInteger(n) && n >= 1) done(n);
        };
        $('modal-no').onclick = () => done(false);
    });
}

/* ---------- views ---------- */
function show(view) {
    closeDds();
    $('root').classList.remove('hidden');
    $('shop').classList.toggle('hidden', view !== 'shop');
    $('admin').classList.toggle('hidden', view !== 'admin');
    $('modal').classList.add('hidden');
}
function closeAll() {
    closeDds();
    $('root').classList.add('hidden');
    $('shop').classList.add('hidden');
    $('admin').classList.add('hidden');
    $('modal').classList.add('hidden');
}
function requestClose() { closeAll(); post('close'); }
document.querySelectorAll('[data-close]').forEach((b) => b.onclick = requestClose);
document.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !$('modal').classList.contains('hidden')) { $('modal-yes').click(); return; }
    if (e.key === 'Escape' && !$('offer').classList.contains('hidden')) { answerOffer(false); return; }
    if (e.key === 'Escape' && !$('root').classList.contains('hidden')) {
        if (!$('modal').classList.contains('hidden')) { $('modal-no').click(); return; }
        requestClose();
    }
});

/* ---------- shop ---------- */
let upBoat = null; // boat id whose upgrades are open
function showPane(name) {
    ['buy', 'owned', 'hire', 'upgrades'].forEach((n) => $('tab-' + n).classList.toggle('hidden', n !== name));
}
document.querySelectorAll('.tab:not(.atab)').forEach((tb) => tb.onclick = () => {
    upBoat = null;
    document.querySelectorAll('.tab:not(.atab)').forEach((x) => x.classList.toggle('active', x === tb));
    showPane(tb.dataset.tab);
});

function renderShop() {
    const d = shopData;
    $('cash').textContent = `$${Number(d.cash || 0).toFixed(2)}`;
    $('boat-count').textContent = d.maxBoats > 0 ? `${d.ownedCount} / ${d.maxBoats}` : String(d.ownedCount);
    const atLimit = d.maxBoats > 0 && d.ownedCount >= d.maxBoats;

    $('tab-buy').innerHTML = d.models.length ? d.models.map((m) => {
        const afford = d.cash >= m.price && !atLimit;
        return `<div class="row">
            <div class="badge-icon">⚓</div>
            <div class="row-body"><div class="row-title">${esc(m.label)}</div><div class="row-desc">${esc(m.description)}</div></div>
            <div class="row-actions"><span class="price ${afford ? '' : 'over'}">$${m.price}</span>
            <button class="wood-btn small" data-buy="${esc(m.model)}" ${afford ? '' : 'disabled'}>${esc(t('ui_buy'))}</button></div></div>`;
    }).join('') : `<div class="empty">${esc(t('ui_none_for_sale'))}</div>`;

    $('tab-owned').innerHTML = d.owned.length ? d.owned.map((b) => `<div class="row">
            <div class="badge-icon">⛵</div>
            <div class="row-body"><div class="row-title">${esc(b.label)}</div><div class="row-desc">${b.here || b.out ? esc(t('ui_sells_for', b.sellPrice)) : esc(t('ui_stored_at', b.storedAt))}</div></div>
            <div class="row-actions">${b.out ? `<span class="pill ok">${esc(t('ui_on_water'))}</span>` : !b.here ? `<span class="pill">${esc(t('ui_elsewhere'))}</span>` : `
                <button class="wood-btn small" data-launch="${b.id}" ${d.hasActive ? 'disabled' : ''}>${esc(t('ui_launch'))}</button>
                ${shopData.canUpgrade ? `<button class="wood-btn small" data-upgrades="${b.id}">${esc(t('ui_upgrades'))}</button>` : ''}
                ${shopData.canTransfer ? `<button class="wood-btn small" data-transfer="${b.id}" data-label="${esc(b.label)}">${esc(t('ui_give'))}</button>` : ''}
                <button class="wood-btn small muted" data-sell="${b.id}" data-label="${esc(b.label)}" data-price="${b.sellPrice}">${esc(t('ui_sell'))}</button>`}</div></div>`).join('')
        : `<div class="empty">${esc(t('ui_none_owned'))}</div>`;

    // hire tab only appears when this yard has boats for hire
    const hire = d.hire || [];
    $('tab-hire-btn').classList.toggle('hidden', !hire.length);
    $('tab-hire').innerHTML = hire.length ? hire.map((m) => {
        const afford = d.cash >= m.rent_price && !d.hasActive;
        return `<div class="row">
            <div class="badge-icon">⚓</div>
            <div class="row-body"><div class="row-title">${esc(m.label)}</div><div class="row-desc">${esc(t('ui_hire_for', d.rentMinutes))}</div></div>
            <div class="row-actions"><span class="price ${d.cash >= m.rent_price ? '' : 'over'}">$${m.rent_price}</span>
            <button class="wood-btn small" data-hire="${esc(m.model)}" ${afford ? '' : 'disabled'}>${esc(t('ui_hire'))}</button></div></div>`;
    }).join('') : '';

    renderUpgrades();
    $('store-row').classList.toggle('hidden', !d.hasActive);
}

function renderUpgrades() {
    if (upBoat === null) return;
    const b = shopData.owned.find((x) => x.id === upBoat);
    if (!b || !b.ups) { upBoat = null; showPane('owned'); return; }
    $('tab-upgrades').innerHTML = `<div class="up-head"><button class="circle-btn" data-upback>‹</button><div class="row-title">${esc(t('ui_up_title', b.label))}</div></div>`
        + b.ups.map((u) => {
            const next = u.price == null ? esc(t('ui_up_maxed'))
                : esc(t(u.key === 'slots' ? 'ui_up_next_slots' : 'ui_up_next_weight', u.key === 'slots' ? u.add : (u.add / 1000).toLocaleString()));
            const afford = u.price != null && shopData.cash >= u.price;
            return `<div class="row">
                <div class="badge-icon">⚙</div>
                <div class="row-body"><div class="row-title">${esc(t('ui_up_' + u.key))}</div><div class="row-desc">${esc(t('ui_up_level', u.level, u.max))} · ${next}</div></div>
                <div class="row-actions">${u.price == null ? '' : `<span class="price ${afford ? '' : 'over'}">$${u.price}</span>
                <button class="wood-btn small" data-up="${u.key}" data-boat="${b.id}" ${afford ? '' : 'disabled'}>${esc(t('ui_up_buy'))}</button>`}</div></div>`;
        }).join('');
}

document.addEventListener('click', async (e) => {
    const b = e.target.closest('button');
    if (!b || busy || b.disabled) return;
    if (b.dataset.buy) {
        busy = true; await post('buy', { model: b.dataset.buy }); busy = false;
    } else if (b.dataset.launch) {
        busy = true; const ok = await post('launch', { id: Number(b.dataset.launch) }); busy = false;
        if (ok) closeAll();
    } else if (b.dataset.hire) {
        busy = true; const ok = await post('rent', { model: b.dataset.hire }); busy = false;
        if (ok) closeAll();
    } else if (b.dataset.upgrades) {
        upBoat = Number(b.dataset.upgrades); showPane('upgrades'); renderUpgrades();
    } else if (b.dataset.upback !== undefined) {
        upBoat = null; showPane('owned');
    } else if (b.dataset.up) {
        busy = true; await post('upgrade', { id: Number(b.dataset.boat), key: b.dataset.up }); busy = false;
    } else if (b.dataset.sell) {
        if (await confirmModal(t('ui_sell_title'), t('ui_sell_text', b.dataset.label, b.dataset.price))) {
            busy = true; await post('sell', { id: Number(b.dataset.sell) }); busy = false;
        }
    } else if (b.dataset.transfer) {
        const target = await confirmModal(t('ui_give_title'), t('ui_give_text', b.dataset.label), true);
        if (target) { busy = true; await post('transfer', { id: Number(b.dataset.transfer), target }); busy = false; }
    } else if (b.dataset.edit) {
        const m = adminData.models.find((x) => x.model === b.dataset.edit);
        if (m) fillForm(m);
    } else if (b.dataset.del) {
        if (await confirmModal(t('ui_remove_model_title'), t('ui_remove_model_text', b.dataset.del))) {
            busy = true; const list = await post('adminDelete', { model: b.dataset.del }); busy = false;
            if (Array.isArray(list)) { adminData.models = list; renderModels(); }
        }
    }
});
$('store-btn').onclick = async () => { if (busy) return; busy = true; await post('store'); busy = false; };

/* ---------- admin ---------- */
let selYard = null;
const fmt = (p) => `X ${Number(p.x).toFixed(2)}  Y ${Number(p.y).toFixed(2)}  Z ${Number(p.z).toFixed(2)}  H ${Number(p.w || 0).toFixed(1)}`;
const curYard = () => adminData && adminData.yards.find((y) => y.id === selYard);

document.querySelectorAll('.atab').forEach((tb) => tb.onclick = () => {
    closeDds();
    document.querySelectorAll('.atab').forEach((x) => x.classList.toggle('active', x === tb));
    $('atab-yards').classList.toggle('hidden', tb.dataset.atab !== 'yards');
    $('atab-models').classList.toggle('hidden', tb.dataset.atab !== 'models');
});

function applyAdmin(res) {
    if (!res || typeof res !== 'object') return false;
    adminData = res;
    if (res.select) selYard = res.select;
    renderAdmin();
    return true;
}

function renderYards() {
    const yards = adminData.yards || [];
    if (!yards.some((y) => y.id === selYard)) selYard = yards.length ? yards[0].id : null;
    const has = yards.length > 0;
    $('yard-detail').classList.toggle('hidden', !has);
    $('yard-empty').classList.toggle('hidden', has);
    $('yard-dd').classList.toggle('hidden', !has);
    if (has) {
        setupDd($('yard-dd'), yards.map((y) => ({ value: String(y.id), label: `#${y.id}  ${y.name}` })), String(selYard),
            (v) => { selYard = Number(v); renderYardDetail(); });
    }
    renderYardDetail();
}

function renderYardDetail() {
    const y = curYard();
    if (!y) return;
    $('yard-name').value = y.name;
    $('yard-text').textContent = fmt(y.coords);
    $('spawn-text').textContent = y.spawn ? fmt(y.spawn) : t('ui_spawn_unset');
    const k = y.dock;
    $('dock-text').textContent = (k.set ? fmt(k) : t('ui_dock_unset')) + '  ·  ' + t('ui_radius_suffix', Number(k.r).toFixed(1));
    $('dock-radius').value = Number(k.r);
    renderYardModels();
}

function renderYardModels() {
    const y = curYard();
    if (!y) return;
    const all = !y.models;
    $('ym-all').dataset.on = all ? '1' : '0';
    $('ym-list').innerHTML = adminData.models.map((m) => {
        const on = all || y.models.includes(m.model);
        return `<label class="toggle" data-ym="${esc(m.model)}"><span class="box" data-on="${on ? 1 : 0}"></span> ${esc(m.label)}</label>`;
    }).join('') || `<div class="empty">${esc(t('ui_no_models'))}</div>`;
    $('ym-list').classList.toggle('off', all);
}
$('ym-all-wrap').onclick = () => {
    const b = $('ym-all'); b.dataset.on = b.dataset.on === '1' ? '0' : '1';
    $('ym-list').classList.toggle('off', b.dataset.on === '1');
};
$('ym-list').addEventListener('click', (e) => {
    const l = e.target.closest('[data-ym]'); if (!l) return;
    e.preventDefault();
    const b = l.querySelector('.box'); b.dataset.on = b.dataset.on === '1' ? '0' : '1';
});
$('ym-save').onclick = () => {
    const all = $('ym-all').dataset.on === '1';
    const models = [...document.querySelectorAll('#ym-list [data-ym]')].filter((l) => l.querySelector('.box').dataset.on === '1').map((l) => l.dataset.ym);
    yardCall('yardModels', { all, models });
};

function renderModels() {
    const d = adminData;
    $('admin-list').innerHTML = d.models.length ? d.models.map((m) => `<div class="row ${m.enabled ? '' : 'disabled'}">
        <div class="badge-icon">⚓</div>
        <div class="row-body"><div class="row-title">${esc(m.label)}</div><div class="row-desc">${esc(t('ui_model_desc', m.model, m.price, m.slots, (m.weight / 1000).toLocaleString()))}${m.rent_price > 0 ? esc(t('ui_rent_suffix', m.rent_price)) : ''}</div></div>
        <div class="row-actions"><span class="pill ${m.enabled ? 'ok' : ''}">${esc(t(m.enabled ? 'ui_on_sale' : 'ui_hidden'))}</span>
        <button class="wood-btn small" data-edit="${esc(m.model)}">${esc(t('ui_edit'))}</button>
        <button class="wood-btn small muted" data-del="${esc(m.model)}">✕</button></div></div>`).join('')
        : `<div class="empty">${esc(t('ui_no_models'))}</div>`;

    const opts = d.models.map((m) => ({ value: m.model, label: m.label }));
    if (!opts.length) opts.push({ value: 'rowboat', label: 'rowboat' });
    const cur = $('placer-dd').dataset.value;
    setupDd($('placer-dd'), opts, opts.some((o) => o.value === cur) ? cur : opts[0].value);
}

function renderAdmin() { renderYards(); renderModels(); }

async function yardCall(name, extra = {}) {
    if (busy) return;
    busy = true; const res = await post(name, Object.assign({ id: selYard }, extra)); busy = false;
    applyAdmin(res);
    return res;
}

$('yard-create-btn').onclick = async () => {
    const name = $('new-yard-name').value.trim();
    if (!name) return;
    if (!(await confirmModal(t('ui_create_title'), t('ui_create_text', name)))) return;
    const res = await yardCall('yardCreate', { name });
    if (res) $('new-yard-name').value = '';
};
$('yard-rename-btn').onclick = () => { const n = $('yard-name').value.trim(); if (n) yardCall('yardRename', { name: n }); };
$('yard-move-btn').onclick = async () => {
    const y = curYard(); if (!y) return;
    if (await confirmModal(t('ui_move_title'), t('ui_move_text', y.name))) yardCall('yardMove');
};
$('yard-delete-btn').onclick = async () => {
    const y = curYard(); if (!y) return;
    if (await confirmModal(t('ui_delete_title'), t('ui_delete_text', y.name))) yardCall('yardDelete');
};
$('dock-here-btn').onclick = () => { const r = Number($('dock-radius').value); if (r > 0) yardCall('adminDock', { r, usePed: true }); };
$('dock-radius-btn').onclick = () => { const r = Number($('dock-radius').value); if (r > 0) yardCall('adminDock', { r, usePed: false }); };
$('place-btn').onclick = () => { if (!selYard) return; closeAll(); post('adminPlace', { id: selYard, model: $('placer-dd').dataset.value }); };

function fillForm(m) {
    $('form-label').textContent = m ? t('ui_edit_model', m.model) : t('ui_add_model');
    $('f-model').value = m ? m.model : '';
    $('f-model').disabled = !!m;
    $('f-label').value = m ? m.label : '';
    $('f-price').value = m ? m.price : '';
    $('f-desc').value = m ? m.description : '';
    $('f-enabled').dataset.on = (!m || m.enabled) ? '1' : '0';
    $('f-slots').value = m ? m.slots : 10;
    $('f-weight').value = m ? m.weight / 1000 : 50;
    $('f-rent').value = m ? (m.rent_price || 0) : 0;
}
$('f-enabled').parentElement.onclick = () => { const b = $('f-enabled'); b.dataset.on = b.dataset.on === '1' ? '0' : '1'; };
$('f-clear').onclick = () => fillForm(null);
$('f-save').onclick = async () => {
    if (busy) return;
    const data = {
        model: $('f-model').value.trim(),
        label: $('f-label').value.trim(),
        price: Number($('f-price').value),
        description: $('f-desc').value.trim(),
        enabled: $('f-enabled').dataset.on === '1',
        slots: Number($('f-slots').value),
        weight: Number($('f-weight').value),
        rentPrice: Number($('f-rent').value || 0),
    };
    if (!data.model || !data.label || !(data.price >= 0) || !(data.slots >= 1) || !(data.weight > 0) || !(data.rentPrice >= 0)) return;
    busy = true; const list = await post('adminSave', data); busy = false;
    if (Array.isArray(list)) { adminData.models = list; renderModels(); fillForm(null); }
};

/* ---------- transfer offer ---------- */
function answerOffer(accepted) {
    if ($('offer').classList.contains('hidden')) return;
    $('offer').classList.add('hidden');
    post('offerAnswer', { accepted });
}
$('offer-yes').onclick = () => answerOffer(true);
$('offer-no').onclick = () => answerOffer(false);

/* ---------- messages from Lua ---------- */
window.addEventListener('message', (e) => {
    const m = e.data || {};
    switch (m.action) {
        case 'openShop':
            applyLocales(m.locales);
            shopData = m.data;
            if (m.title) $('shop-title').textContent = m.title;
            if (m.subtitle) $('shop-subtitle').textContent = m.subtitle;
            upBoat = null;
            document.querySelector('.tab[data-tab="buy"]').click();
            renderShop(); show('shop'); break;
        case 'updateShop':
            shopData = m.data; renderShop(); break;
        case 'openAdmin':
            applyLocales(m.locales);
            adminData = m.data; fillForm(null); renderAdmin(); show('admin'); break;
        case 'close':
            closeAll(); break;
        case 'offer': {
            $('offer-title').textContent = m.title;
            $('offer-text').textContent = m.text;
            $('offer-yes').textContent = m.accept;
            $('offer-no').textContent = m.decline;
            const fill = $('offer-fill');
            fill.style.transition = 'none'; fill.style.width = '100%';
            $('offer').classList.remove('hidden');
            requestAnimationFrame(() => requestAnimationFrame(() => {
                fill.style.transition = `width ${m.timeout || 20}s linear`; fill.style.width = '0%';
            }));
            break;
        }
        case 'offerClose':
            $('offer').classList.add('hidden'); break;
    }
});

/* ---------- draggable panels (drag the header, double-click it to reset) ---------- */
(function () {
    const KEY = 'rsg-boats:pos:';
    const load = (id) => { try { return JSON.parse(localStorage.getItem(KEY + id)) || { x: 0, y: 0 }; } catch (e) { return { x: 0, y: 0 }; } };
    const save = (id, p) => { try { localStorage.setItem(KEY + id, JSON.stringify(p)); } catch (e) {} };

    function clamp(panel, p) {
        // keep at least the header on screen
        const r = panel.getBoundingClientRect();
        const baseL = r.left - p.cur.x, baseT = r.top - p.cur.y;
        const minX = -baseL - r.width + 120, maxX = window.innerWidth - baseL - 120;
        const minY = -baseT, maxY = window.innerHeight - baseT - 60;
        return { x: Math.min(maxX, Math.max(minX, p.x)), y: Math.min(maxY, Math.max(minY, p.y)) };
    }

    ['shop', 'admin'].forEach((id) => {
        const panel = $(id);
        const header = panel.querySelector('.header');
        let pos = load(id);
        const apply = () => { panel.style.transform = `translate(${pos.x}px, ${pos.y}px)`; };
        apply();

        // re-clamp whenever the panel is shown (screen size may have changed)
        new MutationObserver(() => {
            if (!panel.classList.contains('hidden')) requestAnimationFrame(() => { pos = clamp(panel, { x: pos.x, y: pos.y, cur: pos }); apply(); });
        }).observe(panel, { attributes: true, attributeFilter: ['class'] });

        header.addEventListener('mousedown', (e) => {
            if (e.button !== 0 || e.target.closest('button')) return;
            e.preventDefault();
            closeDds();
            const start = { mx: e.clientX, my: e.clientY, x: pos.x, y: pos.y };
            header.classList.add('dragging');
            const move = (ev) => {
                pos = clamp(panel, { x: start.x + ev.clientX - start.mx, y: start.y + ev.clientY - start.my, cur: pos });
                apply();
            };
            const up = () => {
                header.classList.remove('dragging');
                document.removeEventListener('mousemove', move);
                document.removeEventListener('mouseup', up);
                save(id, pos);
            };
            document.addEventListener('mousemove', move);
            document.addEventListener('mouseup', up);
        });

        header.addEventListener('dblclick', (e) => {
            if (e.target.closest('button')) return;
            pos = { x: 0, y: 0 }; apply(); save(id, pos);
        });
    });
})();
