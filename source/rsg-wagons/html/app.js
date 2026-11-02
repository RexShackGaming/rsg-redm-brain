const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'rsg-wagons';
const $ = (id) => document.getElementById(id);

const MAX = { weight: 1700, slots: 100, seats: 8 };
const TIER_ICON = { 1: 'fa-cart-flatbed', 2: 'fa-van-shuttle', 3: 'fa-truck-pickup', 4: 'fa-oil-can' };

const S = {
  strings: {}, store: null, categories: [], wagons: [], owned: [],
  maxWagons: 5, nameMax: 24, hasActive: false,
  tab: 'shop', category: 'all', search: '', selected: null, busy: false,
  livery: -1, tint: -1,
};

function post(name, data = {}) {
  return fetch(`https://${RES}/${name}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data),
  }).then((r) => r.json()).catch(() => ({}));
}

const t = (k, ...args) => {
  let s = S.strings[k] || k;
  args.forEach((a) => { s = s.replace(/%[sd]/, a); });
  return s;
};
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => '$' + Number(n || 0).toLocaleString();

function applyI18n() {
  document.querySelectorAll('[data-i18n]').forEach((el) => { const k = el.dataset.i18n; if (S.strings[k]) el.textContent = S.strings[k]; });
  document.querySelectorAll('[data-i18n-title]').forEach((el) => { const k = el.dataset.i18nTitle; if (S.strings[k]) el.title = S.strings[k]; });
  document.querySelectorAll('[data-i18n-ph]').forEach((el) => { const k = el.dataset.i18nPh; if (S.strings[k]) el.placeholder = S.strings[k]; });
}

/* ================= RENDER ================= */
function renderChips() {
  const chips = [{ id: 'all', icon: 'fa-solid fa-border-all' }, ...S.categories];
  $('categoryChips').innerHTML = chips.map((c) =>
    `<button class="chip ${S.category === c.id ? 'active' : ''}" data-cat="${esc(c.id)}"><i class="${esc(c.icon)}"></i>${esc(t(c.id === 'all' ? 'ui_all' : 'cat_' + c.id))}</button>`
  ).join('');
}

function renderOwnedCount() {
  $('ownedCount').textContent = `${S.owned.length}/${S.maxWagons}`;
}

function renderList() {
  const list = $('list');
  if (S.tab === 'shop') {
    const q = S.search.toLowerCase();
    const items = S.wagons.filter((w) =>
      (S.category === 'all' || w.category === S.category) && (!q || w.label.toLowerCase().includes(q)));
    if (!items.length) { list.innerHTML = `<div class="empty">—</div>`; return; }
    list.innerHTML = items.map((w) => `
      <div class="row ${S.selected === w.model ? 'selected' : ''}" data-model="${esc(w.model)}">
        <span class="badge-icon"><i class="fa-solid ${TIER_ICON[w.tier] || 'fa-truck-pickup'}"></i></span>
        <div class="row-main">
          <div class="row-title">${esc(w.label)}</div>
          <div class="row-sub">${esc(t('cat_' + w.category))} · ${w.weight} ${esc(t('ui_kg'))} · ${w.slots} ${esc(t('ui_slots'))}</div>
        </div>
        <div class="row-right"><span class="row-price">${money(w.price)}</span></div>
      </div>`).join('');
  } else {
    if (!S.owned.length) { list.innerHTML = `<div class="empty">${esc(t('ui_no_owned'))}</div>`; return; }
    list.innerHTML = S.owned.map((o) => {
      const tierCls = o.conditionTier === 'damaged' ? 'bad' : (o.conditionTier === 'poor' ? 'warn' : 'ok');
      return `
      <div class="row ${S.selected === o.id ? 'selected' : ''}" data-id="${o.id}">
        <span class="badge-icon"><i class="fa-solid fa-key"></i></span>
        <div class="row-main">
          <div class="row-title">${esc(o.name)}</div>
          <div class="row-sub">${esc(o.label)} · ${esc(o.active ? t('ui_out') : t('ui_stored_at', o.storeLabel))}</div>
        </div>
        <div class="row-right">
          ${o.active ? `<span class="pill ok">${esc(t('ui_out'))}</span>` : ''}
          <span class="pill ${tierCls}">${esc(t('cond_' + o.conditionTier))}</span>
        </div>
      </div>`;
    }).join('');
  }
}

function setBar(id, value, max, warnBelow) {
  const pct = Math.max(0, Math.min(100, (value / max) * 100));
  const el = $(id);
  el.style.width = pct + '%';
  el.className = 'fill ' + (warnBelow == null ? 'stat-good' : (value < warnBelow[0] ? 'stat-bad' : value < warnBelow[1] ? 'stat-warn' : 'stat-good'));
}

function renderDetails() {
  const box = $('details');
  let w = null; let o = null;
  if (S.tab === 'shop') w = S.wagons.find((x) => x.model === S.selected);
  else { o = S.owned.find((x) => x.id === S.selected); if (o) w = S.wagons.find((x) => x.model === o.model) || o; }
  // the list and the details panel swap: one or the other is shown
  $('catalogue').classList.toggle('hidden', !!w);
  if (!w) { box.classList.add('hidden'); return; }

  box.classList.remove('hidden');
  $('dClass').textContent = t('tier_' + (w.tier || 1));
  $('dName').textContent = o ? o.name : w.label;
  $('dSub').textContent = o ? w.label : t('cat_' + w.category);
  $('dDesc').textContent = w.description || '';
  $('sWeightVal').textContent = `${w.weight} ${t('ui_kg')}`;
  $('sSlotsVal').textContent = w.slots;
  $('sSeatsVal').textContent = w.seats || 2;
  setBar('sWeight', w.weight, MAX.weight);
  setBar('sSlots', w.slots, MAX.slots);
  setBar('sSeats', w.seats || 2, MAX.seats);

  $('condStat').classList.toggle('hidden', !o);
  $('buyBox').classList.toggle('hidden', !!o);
  $('ownedBox').classList.toggle('hidden', !o);

  renderLivery(w, o);

  if (o) {
    $('sCondVal').textContent = `${o.condition}% · ${t('cond_' + o.conditionTier)}`;
    setBar('sCond', o.condition, 100, [90, 96]);
    $('dSell').textContent = money(o.sellValue);
    $('takeOutBtn').disabled = o.active || S.hasActive;
    $('storeBtn').disabled = !o.active;
    $('sellBtn').disabled = o.active;
    $('repairBtn').classList.toggle('hidden', !(o.repairCost > 0) || o.active);
    $('repairText').textContent = `${t('ui_repair')} · ${money(o.repairCost)}`;
  } else {
    $('dPrice').textContent = money(w.price);
    $('buyBtn').disabled = S.owned.length >= S.maxWagons;
  }
}

/* ================= LIVERY ================= */
function liveriesFor(w) { return (w && Array.isArray(w.liveries)) ? w.liveries : []; }

function renderLivery(w, o) {
  // paint is only chosen when buying; owned wagons keep (and preview) their saved paint
  $('paintBox').classList.toggle('hidden', !!o);
  const list = liveriesFor(w);
  const idx = list.findIndex((l) => l.id === S.livery);
  const box = $('paintBox');
  box.classList.toggle('disabled', list.length < 2);
  $('livName').textContent = idx >= 0 ? list[idx].label : t('ui_no_liveries');
  $('livCount').textContent = idx >= 0 ? `${idx + 1} / ${list.length}` : '';
  // colour (tint): -1 = default, then 0..count-1
  const tints = (w && w.tints) || 0;
  $('tintPicker').classList.toggle('off', tints < 1);
  $('tintName').textContent = S.tint < 0 ? t('ui_colour_default') : t('ui_colour_n', S.tint + 1);
  $('tintCount').textContent = tints > 0 ? `${S.tint + 2} / ${tints + 1}` : '';
}

function currentWagon() {
  if (S.tab === 'shop') return { w: S.wagons.find((x) => x.model === S.selected), o: null };
  const o = S.owned.find((x) => x.id === S.selected);
  return { w: o ? (S.wagons.find((x) => x.model === o.model) || o) : null, o };
}

function stepLivery(dir) {
  const { w, o } = currentWagon(); const list = liveriesFor(w);
  if (list.length < 2) return;
  let idx = list.findIndex((l) => l.id === S.livery);
  idx = (idx + dir + list.length) % list.length;
  S.livery = list[idx].id;
  post('previewLivery', { livery: S.livery, tint: S.tint });
  renderLivery(w, o);
}

function stepTint(dir) {
  const { w, o } = currentWagon(); const n = (w && w.tints) || 0;
  if (n < 1) return;
  // cycle through -1 (default) .. n-1
  S.tint = ((S.tint + 1 + dir + n + 1) % (n + 1)) - 1;
  post('previewLivery', { livery: S.livery, tint: S.tint });
  renderLivery(w, o);
}
$('tintPrev').addEventListener('click', () => stepTint(-1));
$('tintNext').addEventListener('click', () => stepTint(1));
$('livPrev').addEventListener('click', () => stepLivery(-1));
$('livNext').addEventListener('click', () => stepLivery(1));

function render() {
  document.querySelectorAll('.tab').forEach((b) => b.classList.toggle('active', b.dataset.tab === S.tab));
  $('shopTools').classList.toggle('hidden', S.tab !== 'shop');
  renderChips(); renderOwnedCount(); renderList(); renderDetails();
}

/* ================= SELECTION / PREVIEW ================= */
function select(key) {
  S.selected = key;
  const { w, o } = currentWagon();
  const list = liveriesFor(w);
  S.livery = o && o.livery >= 0 ? o.livery : (list.length ? list[0].id : -1);
  S.tint = o ? (o.tint ?? -1) : -1;
  const model = o ? o.model : (w && w.model);
  if (model) post('preview', { model, livery: S.livery, tint: S.tint });
  render();
}

function setOwned(owned, hasActive) {
  if (Array.isArray(owned)) S.owned = owned;
  if (typeof hasActive === 'boolean') S.hasActive = hasActive;
  else S.hasActive = S.owned.some((o) => o.active);
  if (S.tab === 'owned' && !S.owned.find((o) => o.id === S.selected)) S.selected = null;
  render();
}

/* ================= MODALS ================= */
let inputCb = null; let confirmCb = null;
function askName(title, value, cb) {
  $('inputTitle').textContent = title;
  const f = $('inputField'); f.maxLength = S.nameMax; f.value = value || '';
  $('inputModal').classList.remove('hidden');
  inputCb = cb; setTimeout(() => f.focus(), 30);
}
function closeInput() { $('inputModal').classList.add('hidden'); inputCb = null; }
function askConfirm(text, cb) { $('confirmText').textContent = text; $('confirmModal').classList.remove('hidden'); confirmCb = cb; }
function closeConfirm() { $('confirmModal').classList.add('hidden'); confirmCb = null; }

$('inputOk').addEventListener('click', () => { const v = $('inputField').value.trim(); const cb = inputCb; closeInput(); if (cb) cb(v); });
$('inputCancel').addEventListener('click', closeInput);
$('inputField').addEventListener('keydown', (e) => { if (e.key === 'Enter') $('inputOk').click(); });
$('confirmOk').addEventListener('click', () => { const cb = confirmCb; closeConfirm(); if (cb) cb(); });
$('confirmCancel').addEventListener('click', closeConfirm);

/* ================= ACTIONS ================= */
async function guarded(fn) { if (S.busy) return; S.busy = true; try { await fn(); } finally { S.busy = false; } }

$('buyBtn').addEventListener('click', () => {
  const w = S.wagons.find((x) => x.model === S.selected); if (!w) return;
  askName(t('ui_name_wagon'), w.label, (name) => guarded(async () => {
    const r = await post('buy', { model: w.model, name, livery: S.livery, tint: S.tint });
    if (r.ok) setOwned(r.owned);
  }));
});

$('takeOutBtn').addEventListener('click', () => guarded(async () => {
  if (S.selected == null) return;
  await post('takeOut', { id: S.selected });
}));

$('storeBtn').addEventListener('click', () => guarded(async () => {
  const r = await post('store', {});
  if (r.ok) setOwned(r.owned, r.hasActive);
}));

$('repairBtn').addEventListener('click', () => guarded(async () => {
  const o = S.owned.find((x) => x.id === S.selected); if (!o) return;
  const r = await post('yardRepair', { id: o.id });
  if (r.ok) setOwned(r.owned, S.hasActive);
}));

$('renameBtn').addEventListener('click', () => {
  const o = S.owned.find((x) => x.id === S.selected); if (!o) return;
  askName(t('ui_rename'), o.name, (name) => guarded(async () => {
    if (!name) return;
    const r = await post('rename', { id: o.id, name });
    if (r.ok) setOwned(r.owned, S.hasActive);
  }));
});

$('sellBtn').addEventListener('click', () => {
  const o = S.owned.find((x) => x.id === S.selected); if (!o) return;
  askConfirm(t('ui_sell_confirm', o.name, money(o.sellValue)), () => guarded(async () => {
    const r = await post('sell', { id: o.id });
    if (r.ok) { S.selected = null; post('clearPreview'); setOwned(r.owned, S.hasActive); }
  }));
});

/* ================= UI EVENTS ================= */
document.querySelectorAll('.tab').forEach((b) => b.addEventListener('click', () => {
  if (S.tab === b.dataset.tab) return;
  S.tab = b.dataset.tab; S.selected = null; post('clearPreview'); render();
}));

$('categoryChips').addEventListener('click', (e) => {
  const c = e.target.closest('.chip'); if (!c) return;
  S.category = c.dataset.cat; render();
});

$('search').addEventListener('input', (e) => { S.search = e.target.value; renderList(); });

$('list').addEventListener('click', (e) => {
  const r = e.target.closest('.row'); if (!r || r.classList.contains('disabled')) return;
  if (r.dataset.model) select(r.dataset.model);
  else if (r.dataset.id) select(Number(r.dataset.id));
});

$('closeBtn').addEventListener('click', () => post('close'));

// back from the details panel to the wagon list
function backToList() {
  if (S.selected == null) return false;
  S.selected = null; post('rotateCam', { dir: null }); post('clearPreview'); render();
  return true;
}
$('backBtn').addEventListener('click', backToList);

// camera controls: hold to rotate, click / wheel to zoom
document.querySelectorAll('[data-rotate]').forEach((b) => {
  b.addEventListener('mousedown', () => post('rotateCam', { dir: b.dataset.rotate }));
  ['mouseup', 'mouseleave'].forEach((ev) => b.addEventListener(ev, () => post('rotateCam', { dir: null })));
});
document.querySelectorAll('[data-zoom]').forEach((b) => b.addEventListener('click', () => post('zoomCam', { dir: Number(b.dataset.zoom) })));

window.addEventListener('wheel', (e) => {
  if ($('app').classList.contains('hidden') || S.selected == null) return;
  // let lists/panels scroll, except over the camera row in the details panel
  if ((e.target.closest('.panel') && !e.target.closest('.cam-row')) || e.target.closest('.modal')) return;
  post('zoomCam', { dir: e.deltaY > 0 ? 1 : -1 });
}, { passive: true });

let keyRotate = null;
window.addEventListener('keydown', (e) => {
  if ($('app').classList.contains('hidden')) return;
  if (e.key === 'Escape') {
    if (!$('inputModal').classList.contains('hidden')) return closeInput();
    if (!$('confirmModal').classList.contains('hidden')) return closeConfirm();
    if (backToList()) return;
    return post('close');
  }
  if (document.activeElement && document.activeElement.tagName === 'INPUT') return;
  const k = e.key.toLowerCase();
  const dir = (k === 'a' || e.key === 'ArrowLeft') ? 'left' : (k === 'd' || e.key === 'ArrowRight') ? 'right' : null;
  if (dir && keyRotate !== dir) { keyRotate = dir; post('rotateCam', { dir }); }
});
window.addEventListener('keyup', (e) => {
  const k = e.key.toLowerCase();
  if (keyRotate && ['a', 'd', 'arrowleft', 'arrowright'].includes(k)) { keyRotate = null; post('rotateCam', { dir: null }); }
});

/* ================= CUSTOMISE (cargo / lanterns) ================= */
// index 0 = none, 1..n = list entries
const C = { props: [], lanterns: [], p: 0, l: 0 };
const customOpen = () => !$('custom').classList.contains('hidden');
const pick = (list, i) => (i > 0 && list[i - 1] ? list[i - 1].name : null);

function renderCustom() {
  const show = (box, list, i, nameId, countId) => {
    $(box).classList.toggle('hidden', list.length === 0);
    $(nameId).textContent = i > 0 ? list[i - 1].label : t('ui_none');
    $(countId).textContent = `${i + 1} / ${list.length + 1}`;
  };
  show('cargoBox', C.props, C.p, 'cargoName', 'cargoCount');
  show('lanternBox', C.lanterns, C.l, 'lanternName', 'lanternCount');
}
function stepCustom(kind, dir) {
  const list = kind === 'p' ? C.props : C.lanterns; const n = list.length + 1;
  C[kind] = (C[kind] + dir + n) % n;
  post('customPreview', { propset: pick(C.props, C.p), lantern: pick(C.lanterns, C.l) });
  renderCustom();
}
$('cargoPrev').addEventListener('click', () => stepCustom('p', -1));
$('cargoNext').addEventListener('click', () => stepCustom('p', 1));
$('lanternPrev').addEventListener('click', () => stepCustom('l', -1));
$('lanternNext').addEventListener('click', () => stepCustom('l', 1));
$('customCancel').addEventListener('click', () => post('customClose'));
$('customSave').addEventListener('click', () => guarded(async () => {
  await post('customSave', { propset: pick(C.props, C.p), lantern: pick(C.lanterns, C.l) });
}));
window.addEventListener('keydown', (e) => { if (e.key === 'Escape' && customOpen()) post('customClose'); });

/* ================= NUI MESSAGES ================= */
window.addEventListener('message', (e) => {
  const d = e.data || {};
  if (d.action === 'open') {
    S.strings = d.strings || {}; S.store = d.store; S.categories = d.categories || [];
    S.wagons = d.wagons || []; S.owned = d.owned || []; S.maxWagons = d.maxWagons || 5; S.nameMax = d.nameMax || 24;
    S.hasActive = !!d.hasActive || S.owned.some((o) => o.active);
    S.tab = 'shop'; S.category = 'all'; S.search = ''; S.selected = null; S.busy = false;
    $('search').value = '';
    $('storeLabel').textContent = d.store ? d.store.label : '';
    applyI18n(); closeInput(); closeConfirm(); render();
    $('app').classList.remove('hidden');
  } else if (d.action === 'custom') {
    S.strings = d.strings || S.strings; applyI18n(); S.busy = false;
    C.props = d.propsets || []; C.lanterns = d.lanterns || [];
    C.p = Math.max(0, C.props.findIndex((x) => x.name === d.propset) + 1);
    C.l = Math.max(0, C.lanterns.findIndex((x) => x.name === d.lantern) + 1);
    $('customName').textContent = d.name || '';
    renderCustom();
    $('custom').classList.remove('hidden');
  } else if (d.action === 'closeCustom') {
    $('custom').classList.add('hidden');
  } else if (d.action === 'close') {
    closeInput(); closeConfirm();
    $('app').classList.add('hidden');
  }
});
