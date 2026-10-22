const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-farming';
const $ = (id) => document.getElementById(id);
const app = $('app'), plantPanel = $('plant-panel'), listPanel = $('list-panel');
let current = null;     // plant open in the single view
let fromPlant = false;  // list was opened from the plant view (back returns there)
let L = {};             // locale strings sent from Lua

// t('ui_stage', 1, 4) -> "Stage 1 / 4"
const t = (key, ...args) => {
    let i = 0;
    return (L[key] || key).replace(/%s/g, () => (args[i++] ?? ''));
};

function applyLocale() {
    document.querySelectorAll('[data-i18n]').forEach((el) => { if (L[el.dataset.i18n]) el.textContent = L[el.dataset.i18n]; });
    document.querySelectorAll('[data-i18n-title]').forEach((el) => { if (L[el.dataset.i18nTitle]) el.title = L[el.dataset.i18nTitle]; });
}

function post(name, data = {}) {
    return fetch(`https://${RES}/${name}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data)
    }).catch(() => {});
}

const escapeHtml = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const clampPct = (v) => Math.max(0, Math.min(100, Number(v) || 0));
const level = (v) => (v >= 50 ? 'stat-good' : v >= 20 ? 'stat-warn' : 'stat-bad');
const growthLevel = (v) => (v >= 100 ? 'stat-good' : 'stat-warn');

function setBar(key, value, klass) {
    const bar = $(`b-${key}`);
    bar.style.width = `${clampPct(value)}%`;
    bar.className = `fill ${klass}`;
    $(`v-${key}`).textContent = `${Math.round(value)}%`;
}

function statusOf(p) {
    if (p.dead) return { text: t('ui_dead'), cls: 'bad' };
    if (p.ready) return { text: t('ui_ready'), cls: 'good' };
    if (p.thirsty) return { text: t('ui_needs_water'), cls: 'bad' };
    if (p.water < 25) return { text: t('ui_thirsty'), cls: 'warn' };
    return { text: t('ui_growing'), cls: '' };
}

function renderPlant(p) {
    current = p;
    $('p-label').textContent = p.label;
    $('p-sub').textContent = p.dead ? t('ui_withered') : t('ui_stage', p.stage, p.stages);

    const s = statusOf(p);
    const pill = $('p-status');
    pill.textContent = s.text;
    pill.className = `status-pill ${s.cls}`;

    setBar('growth', p.growth, growthLevel(p.growth));
    setBar('water', p.water, level(p.water));
    setBar('fert', p.fertilizer, p.fertilizer > 0 ? level(p.fertilizer) : 'stat-bad');
    setBar('health', p.health, level(p.health));

    let note;
    if (p.dead) note = t('ui_note_dead');
    else if (p.ready) note = t('ui_note_ready');
    else if (p.thirsty) note = t('ui_note_dry');
    else note = t(p.remaining === 1 ? 'ui_note_minute' : 'ui_note_minutes', p.remaining) + (p.fertilizer > 0 ? t('ui_note_fertilised') : '') + '.';
    if (!p.isOwner) note += t('ui_not_yours');
    $('p-note').textContent = note;

    const btn = (a) => document.querySelector(`[data-act="${a}"]`);
    btn('water').disabled = p.dead || p.water >= 95;
    btn('fertilize').disabled = p.dead || p.fertilizer >= 95 || p.growth >= 100;
    btn('harvest').disabled = !p.ready || (p.ownerOnly && !p.isOwner);
    btn('destroy').disabled = !p.isOwner && !p.dead;
}

function miniBar(label, value, klass) {
    return `<div><label>${escapeHtml(label)}</label><div class="track small"><div class="fill ${klass}" style="width:${clampPct(value)}%"></div></div></div>`;
}

function renderList(plants) {
    $('l-sub').textContent = t(plants.length === 1 ? 'ui_plant_count' : 'ui_plants_count', plants.length);
    const list = $('list');
    list.innerHTML = '';
    if (!plants.length) {
        list.innerHTML = `<div class="empty">${escapeHtml(t('ui_empty'))}</div>`;
        return;
    }
    const frag = document.createDocumentFragment();
    plants.forEach((p) => {
        const s = statusOf(p);
        const row = document.createElement('div');
        row.className = 'row';
        row.innerHTML = `
            <div class="badge-icon">&#10048;</div>
            <div class="row-body">
                <div class="row-title">${escapeHtml(p.label)}</div>
                <div class="row-desc">${escapeHtml(p.dead ? t('ui_withered') : t('ui_stage', p.stage, p.stages))} · ${escapeHtml(t('ui_away', p.distance))}</div>
                <div class="mini">
                    ${miniBar(t('ui_growth'), p.growth, growthLevel(p.growth))}
                    ${miniBar(t('ui_water'), p.water, level(p.water))}
                    ${miniBar(t('ui_health'), p.health, level(p.health))}
                </div>
            </div>
            <span class="pill ${s.cls}">${escapeHtml(s.text)}</span>`;
        row.addEventListener('click', () => { close(false); post('openPlant', { id: p.id }); });
        frag.appendChild(row);
    });
    list.appendChild(frag);
}

function show(panel) {
    app.classList.remove('hidden');
    plantPanel.classList.toggle('hidden', panel !== 'plant');
    listPanel.classList.toggle('hidden', panel !== 'list');
}

function close(notify = true) {
    app.classList.add('hidden');
    plantPanel.classList.add('hidden');
    listPanel.classList.add('hidden');
    current = null;
    fromPlant = false;
    if (notify) post('close');
}

window.addEventListener('message', ({ data }) => {
    switch (data.action) {
        case 'locale': L = data.strings || {}; applyLocale(); break;
        case 'open':   fromPlant = false; renderPlant(data.plant); show('plant'); break;
        case 'update': if (current && current.id === data.plant.id) renderPlant(data.plant); break;
        case 'list':   renderList(data.plants || []); show('list'); break;
        case 'close':  close(false); break;
    }
});

document.querySelectorAll('[data-act]').forEach((b) =>
    b.addEventListener('click', () => {
        if (!current || b.disabled) return;
        const id = current.id;
        close(false);
        post('action', { action: b.dataset.act, id });
    })
);
document.querySelectorAll('.btn-close').forEach((b) => b.addEventListener('click', () => close()));
$('btn-list').addEventListener('click', () => { const back = current; post('showList'); fromPlant = back; });
$('btn-back').addEventListener('click', () => {
    if (fromPlant) { const p = fromPlant; fromPlant = false; renderPlant(p); show('plant'); post('reopen', { id: p.id }); }
    else close();
});
document.addEventListener('keydown', (e) => { if (e.key === 'Escape' || e.key === 'Backspace') close(); });
