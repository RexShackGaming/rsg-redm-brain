const res = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'rsg-mapping';
const post = (ev, data = {}) => fetch(`https://${res}/${ev}`, {
  method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data)
}).then(r => r.json()).catch(() => null);
const $ = id => document.getElementById(id);
const hex = h => '0x' + ((h >>> 0).toString(16).toUpperCase().padStart(8, '0'));
const isOpen = el => !el.classList.contains('hidden');

let items = [], filter = 'all', current = null, maxResults = 200;
let globalHit = null, lastLookup = null, lookupTimer = null, viewing = false, labelsOn = false;

// ---- locale ----
let L = {};
const t = (k, ...a) => { let s = L[k] || k; a.forEach(v => { s = s.replace(/%s/, v); }); return s; };
function applyStrings(strings) {
  if (strings) L = strings;
  document.querySelectorAll('[data-i18n]').forEach(e => { if (L[e.dataset.i18n]) e.textContent = L[e.dataset.i18n]; });
  document.querySelectorAll('[data-i18n-ph]').forEach(e => { e.placeholder = t(e.dataset.i18nPh); });
  document.querySelectorAll('[data-i18n-title]').forEach(e => { e.title = t(e.dataset.i18nTitle); });
}

// ---- toasts / clipboard ----
function toast(msg, type = 'info') {
  const el = document.createElement('div');
  el.className = `toast ${type}`;
  el.innerHTML = '<div class="tl"></div><div class="tm"></div>';
  el.querySelector('.tl').textContent = type === 'error' ? t('t_error') : type === 'success' ? t('t_success') : t('t_imap');
  el.querySelector('.tm').textContent = msg;
  $('toasts').appendChild(el);
  setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 260); }, 2600);
}

function copy(text) {
  const c = $('clip'); c.value = text; c.select(); document.execCommand('copy');
  toast(t('t_copied'), 'success');
}

// ---- search ----
// parse "0x1130D783", "1130D783" or "288413571" / "-1378517036" -> signed int32, else null
function parseHash(q) {
  q = q.trim().toLowerCase();
  let n = null;
  if (/^0x[0-9a-f]{1,8}$/.test(q)) n = parseInt(q, 16);
  else if (/^-?\d+$/.test(q)) n = parseInt(q, 10);
  else if (/^[0-9a-f]{8}$/.test(q)) n = parseInt(q, 16);
  return n === null || isNaN(n) ? null : (n | 0);
}
function matches(v, q) {
  if (v.name.toLowerCase().includes(q) || (v.label || '').toLowerCase().includes(q)) return true;
  if (/^(0x)?[0-9a-f]+$/.test(q) && hex(v.hash).toLowerCase().slice(2).includes(q.replace(/^0x/, ''))) return true;
  return String(v.hash).includes(q) || String(v.hash >>> 0).includes(q);
}
async function lookupHash(q) {
  const h = parseHash(q);
  if (h === null || items.some(i => i.hash === h)) { globalHit = null; lastLookup = null; return; }
  if (lastLookup === h) return;
  lastLookup = h;
  const r = await post('findHash', { hash: h });
  globalHit = r && r.length ? r[0] : null;
  if (!globalHit) toast(t('t_not_found'), 'error');
  render();
}

// ---- list ----
function render() {
  const q = $('search').value.trim().toLowerCase();
  const shown = items.filter(v => (filter === 'all' || (filter === 'active') === v.active) && (!q || matches(v, q)));
  if (globalHit && q && parseHash(q) === globalHit.hash && !shown.some(v => v.hash === globalHit.hash)) shown.unshift(globalHit);

  const active = items.filter(v => v.active).length;
  $('subtitle').textContent = t('ui_found', items.length, $('radius').value);
  $('countActive').textContent = t('ui_active_count', active);
  $('activeBar').style.width = items.length ? (active / items.length * 100) + '%' : '0';

  const list = $('list');
  const frag = document.createDocumentFragment();
  const modalOpen = isOpen($('modal'));
  shown.slice(0, maxResults).forEach(v => {
    const el = document.createElement('div');
    el.className = 'item' + (v.active ? ' active' : '') + (modalOpen && current && current.hash === v.hash ? ' selected' : '');
    el.innerHTML = `<div class="badge-ico"><div class="dot"></div></div>
      <div class="info"><div class="name"></div><div class="desc"><span class="meta"></span><span class="raw"></span></div></div>
      <div class="pill${v.saved != null ? ' saved' : ''}"></div>`;
    el.querySelector('.name').textContent = v.label || v.name;
    el.querySelector('.meta').textContent = `${v.global ? t('ui_outside') + ' · ' : ''}${v.dist.toFixed(1)}m · ${hex(v.hash)}`;
    if (v.label) el.querySelector('.raw').textContent = ' · ' + v.name;
    const pill = el.querySelector('.pill');
    pill.textContent = (v.active ? t('ui_active') : t('ui_inactive')) + (v.saved != null ? ' 💾' : '');
    if (v.saved != null) pill.title = t('ui_state_saved');
    el.onclick = () => openModal(v);
    frag.appendChild(el);
  });
  list.replaceChildren(frag);
  if (!shown.length) {
    const empty = document.createElement('div');
    empty.className = 'empty'; empty.textContent = t('ui_none');
    list.replaceChildren(empty);
  }
}

// ---- details modal ----
function setView(on) {
  viewing = on;
  $('mView').textContent = on ? t('ui_exit_view') : t('ui_view');
  $('mView').classList.toggle('on', on);
}
function setLabels(on) {
  labelsOn = !!on;
  $('labelsBtn').textContent = labelsOn ? t('ui_labels_on') : t('ui_labels_off');
  $('labelsBtn').classList.toggle('on', labelsOn);
}

function fillModal(v) {
  const unnamed = t('ui_unnamed');
  $('mTitle').textContent = v.label || v.name || unnamed;
  $('mRaw').textContent = v.name || unnamed;
  $('mSaved').textContent = v.saved == null ? t('ui_saved_none') : (v.saved == 1 || v.saved === true ? t('ui_enabled') : t('ui_disabled'));
  $('mStatus').textContent = v.active ? t('ui_active') : t('ui_inactive');
  $('mStatus').style.color = v.active ? 'var(--rdr-cost-ok)' : 'var(--rdr-muted)';
  $('mDist').textContent = v.dist.toFixed(1) + 'm';
  $('mHash').textContent = `${hex(v.hash)} / ${v.hash}`;
  $('mCoords').textContent = `${v.x.toFixed(1)}, ${v.y.toFixed(1)}, ${v.z.toFixed(1)}`;
  $('mToggle').textContent = v.active ? t('ui_disable') : t('ui_enable');
  $('mForget').disabled = v.saved == null;
}

function openModal(v) {
  if (current && current.hash !== v.hash) setView(false);
  current = v;
  $('mLabel').value = v.label || '';
  fillModal(v);
  $('modal').classList.remove('hidden');
  post('select', { x: v.x, y: v.y, z: v.z, name: v.label || v.name || t('ui_unnamed'), hash: v.hash, active: v.active });
  render();
}

function closeModal() {
  setView(false);
  $('modal').classList.add('hidden');
  current = null;
  post('deselect');
  render();
}

function closeUI() {
  setView(false);
  $('modal').classList.add('hidden');
  $('app').classList.add('hidden');
  current = null;
  post('close');
}

async function rescan() {
  const data = await post('scan', { radius: Number($('radius').value) });
  if (data) { items = data; globalHit = null; lastLookup = null; render(); }
}

// ---- NUI messages ----
window.addEventListener('message', e => {
  const d = e.data;
  if (d.action === 'open') {
    applyStrings(d.strings);
    items = d.items || []; maxResults = d.maxResults || 200; $('radius').value = d.radius;
    globalHit = null; lastLookup = null;
    setLabels(d.labels); setView(false);
    $('app').classList.remove('hidden');
    render();
    requestAnimationFrame(() => window.dispatchEvent(new Event('resize'))); // re-clamp saved panel position
    $('search').focus();
  } else if (d.action === 'saved') {
    const upd = v => { v.label = d.label || null; v.saved = d.state == null ? null : d.state; };
    const it = items.find(i => i.hash === d.hash); if (it) upd(it);
    if (globalHit && globalHit.hash === d.hash) upd(globalHit);
    if (current && current.hash === d.hash) { if (current !== it) upd(current); fillModal(current); }
    render();
  }
});

// ---- controls ----
$('closeBtn').onclick = closeUI;
$('refreshBtn').onclick = rescan;
$('search').oninput = () => {
  render();
  clearTimeout(lookupTimer);
  lookupTimer = setTimeout(() => lookupHash($('search').value), 300);
};
$('radius').onchange = rescan;
$('filters').onclick = e => {
  const f = e.target.dataset.f; if (!f) return;
  filter = f;
  document.querySelectorAll('#filters button').forEach(b => b.classList.toggle('active', b.dataset.f === f));
  render();
};
$('labelsBtn').onclick = async () => {
  const r = await post('toggleLabels', { radius: Number($('radius').value) });
  if (r) setLabels(r.on);
};

$('mClose').onclick = closeModal;
$('mToggle').onclick = async () => {
  const v = current; if (!v) return;
  $('mToggle').disabled = true;
  const r = await post('toggle', { hash: v.hash, name: v.name, enable: !v.active });
  $('mToggle').disabled = false;
  if (!r) return;
  v.active = r.active;
  if (r.saved != null) v.saved = r.saved;
  const it = items.find(i => i.hash === v.hash); if (it && it !== v) { it.active = v.active; it.saved = v.saved; }
  toast(t(r.active ? 't_enabled' : 't_disabled', v.label || v.name), r.active ? 'success' : 'info');
  if (current === v) { fillModal(v); post('select', { x: v.x, y: v.y, z: v.z, name: v.label || v.name, hash: v.hash, active: v.active }); }
  render();
};
$('mWaypoint').onclick = async () => {
  if (!current) return;
  if (await post('waypoint', { x: current.x, y: current.y, z: current.z })) toast(t('t_waypoint'), 'success');
};
$('mView').onclick = async () => {
  if (!current) return;
  const r = await post('view', { on: !viewing, x: current.x, y: current.y, z: current.z });
  setView(!!(r && r.on));
};
document.querySelectorAll('[data-copy]').forEach(b => b.onclick = () => {
  const v = current, k = b.dataset.copy; if (!v) return;
  copy(k === 'name' ? v.name : k === 'hash' ? hex(v.hash)
    : k === 'lua' ? `RequestImap(${hex(v.hash)}) -- ${v.name}`
    : `vector3(${v.x.toFixed(2)}, ${v.y.toFixed(2)}, ${v.z.toFixed(2)})`);
});

// friendly names + saved state
$('mSaveLabel').onclick = () => {
  if (!current) return;
  const label = $('mLabel').value.trim();
  post('setLabel', { hash: current.hash, name: current.name, label });
  toast(label ? t('t_label_saved', label) : t('t_label_cleared'), 'success');
};
$('mLabel').addEventListener('keydown', e => { if (e.key === 'Enter') $('mSaveLabel').click(); });
$('mForget').onclick = () => {
  if (!current) return;
  post('forgetState', { hash: current.hash, name: current.name });
  toast(t('t_forgot'), 'info');
};

document.addEventListener('keydown', e => {
  if (e.key !== 'Escape' || !isOpen($('app'))) return;
  if (isOpen($('modal'))) closeModal(); else closeUI();
});

// ---- draggable element helper (drag handle, double-click handle to reset) ----
function makeDraggable(el, handle, key, useTranslate) {
  let pos = null, start = null, dragging = false;
  const save = () => { try { localStorage.setItem(key, JSON.stringify(pos)); } catch (e) {} };
  const clear = () => { try { localStorage.removeItem(key); } catch (e) {} };

  const apply = () => {
    if (!pos) { el.style.left = el.style.top = el.style.right = el.style.transform = ''; return; }
    if (useTranslate) { el.style.transform = `translate(${pos.x}px, ${pos.y}px)`; return; }
    const x = Math.min(Math.max(pos.x, 0), window.innerWidth - el.offsetWidth);
    const y = Math.min(Math.max(pos.y, 0), window.innerHeight - el.offsetHeight);
    el.style.left = x + 'px'; el.style.top = y + 'px'; el.style.right = 'auto'; el.style.transform = 'none';
  };

  try { pos = JSON.parse(localStorage.getItem(key)); } catch (e) { pos = null; }
  requestAnimationFrame(apply);

  handle.addEventListener('mousedown', e => {
    if (e.button !== 0 || e.target.closest('button')) return;
    const r = el.getBoundingClientRect();
    start = useTranslate
      ? { mx: e.clientX, my: e.clientY, x: pos ? pos.x : 0, y: pos ? pos.y : 0, baseL: r.left - (pos ? pos.x : 0), baseT: r.top - (pos ? pos.y : 0), w: r.width, h: r.height }
      : { dx: e.clientX - r.left, dy: e.clientY - r.top };
    dragging = true; el.classList.add('dragging'); e.preventDefault();
  });
  document.addEventListener('mousemove', e => {
    if (!dragging) return;
    if (useTranslate) {
      const s = start;
      pos = {
        x: Math.min(Math.max(s.x + e.clientX - s.mx, -s.baseL), window.innerWidth - s.w - s.baseL),
        y: Math.min(Math.max(s.y + e.clientY - s.my, -s.baseT), window.innerHeight - s.h - s.baseT),
      };
    } else pos = { x: e.clientX - start.dx, y: e.clientY - start.dy };
    apply();
  });
  document.addEventListener('mouseup', () => {
    if (!dragging) return;
    dragging = false; el.classList.remove('dragging'); save();
  });
  handle.addEventListener('dblclick', e => {
    if (e.target.closest('button')) return;
    pos = null; apply(); clear();
  });
  window.addEventListener('resize', apply);
}

makeDraggable(document.querySelector('.panel'), document.querySelector('.header'), 'rsg-mapping-pos', false);
makeDraggable(document.querySelector('.modal'), $('mHandle'), 'rsg-mapping-modal-pos', true);
