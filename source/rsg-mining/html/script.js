const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-mining';
let state = null;
let tab = 'overview';

const post = (name, data = {}) => fetch(`https://${RES}/${name}`, {
  method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data)
}).catch(() => {});

// ---- locales (sent from ox_lib on open; %s placeholders filled in order) ----
let LOC = {};
const t = (key, ...args) => {
  let i = 0;
  return String(LOC[key] ?? key).replace(/%s/g, () => (i < args.length ? args[i++] : ''));
};
function applyStaticLocales() {
  document.querySelectorAll('[data-i18n]').forEach(el => { el.textContent = t(el.dataset.i18n); });
  document.querySelectorAll('[data-i18n-title]').forEach(el => { el.title = t(el.dataset.i18nTitle); });
}

const esc = s => String(s).replace(/[&<>"']/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[c]));
const lvl = v => v > 60 ? 'stat-good' : v > 25 ? 'stat-warn' : 'stat-bad';
const FALLBACK = { bread: '&#x1F35E;', water: '&#x1F4A7;', pickaxe: '&#x26CF;' };
const itemIcon = (d, image, fb = '&#x1FAA8;') => image
  ? `<div class="badge-icon item-icon"><img src="${esc(d.imagePath + image)}" alt="" onerror="this.parentNode.innerHTML='${fb}'"></div>`
  : `<div class="badge-icon">${fb}</div>`;
const bar = v => `<div class="bar"><div class="fill ${lvl(v)}" style="width:${Math.max(0, Math.min(100, v))}%"></div></div>`;

function fmtTime(sec) {
  if (sec <= 0) return t('ui_expired');
  const d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60);
  return d > 0 ? t('ui_time_days', d, h, m) : t('ui_time_hours', h, m);
}

// live countdown: element holds the local timestamp it reaches zero, ticked once a second
let receivedAt = Date.now();
const countdown = sec => `<span data-until="${receivedAt + sec * 1000}">${fmtTime(sec)}</span>`;
setInterval(() => {
  if (!state || isHidden()) return;
  document.querySelectorAll('[data-until]').forEach(el => {
    el.textContent = fmtTime(Math.floor((Number(el.dataset.until) - Date.now()) / 1000));
  });
}, 1000);

// status -> pill colour; text comes from status_<name> locale keys
const STATUS = {
  working: 'good', idle: 'warn', hungry: 'bad', thirsty: 'bad', no_pickaxe: 'bad', storage_full: 'warn', strike: 'bad'
};

function renderOverview(d) {
  const left = d.expires - d.now;
  const working = d.workers.filter(w => w.status === 'working').length;
  const strikers = d.workers.filter(w => w.status === 'strike').length;
  document.getElementById('tab-overview').innerHTML = `
    <div class="summary">
      <div class="row"><span class="label">${t('ui_lease_remaining')}</span><span class="big">${countdown(left)}</span></div>
      <div class="row"><span class="label">${t('ui_crew')}</span><span class="big">${d.workers.length} / ${d.maxWorkers}</span><span class="desc">${t('ui_working', working)}</span></div>
      <div class="row"><span class="label">${t('ui_storage')}</span><span class="big">${d.storageUsed} / ${d.storageCap}</span></div>
      <div class="row"><span class="label">${t('ui_shift_length')}</span><span class="big">${t('ui_minutes', d.workInterval)}</span></div>
    </div>
    <div class="divider"><span>&#x2726;</span></div>
    <div class="label">${t('ui_payroll')}</div>
    <div class="row"><div class="badge-icon">&#x1F4B0;</div>
      <div class="grow"><div class="name">${t('ui_in_fund', d.wages)}</div>
        <div class="desc">${t('ui_cost_per_shift', d.payroll)} &middot; ${d.payroll > 0 ? t('ui_shifts_covered', Math.floor(d.wages / d.payroll)) : t('ui_no_crew')}${strikers ? ` &middot; <b>${t('ui_on_strike_count', strikers)}</b>` : ''}</div></div>
      <input type="number" min="1" value="${Math.max(1, d.payroll * 5)}" id="amt-wages">
      <button class="wood-btn" data-act="addWages" ${d.wages >= d.maxPayroll ? 'disabled' : ''}>${t('ui_pay_in')}</button>
      ${d.canWithdraw ? `<button class="wood-btn muted" data-act="withdrawWages" ${d.wages < 1 ? 'disabled' : ''}>${t('ui_take_out')}</button>` : ''}
    </div>
    <div class="divider"><span>&#x2726;</span></div>
    <div class="label">${t('ui_mine_stores')}</div>
    ${['bread', 'water', 'pickaxe'].map(k => `
      <div class="row">${itemIcon(d, d.supplyCfg[k].image, FALLBACK[k])}
      <div class="grow"><div class="name">${esc(d.supplyCfg[k].label)}</div><div class="desc">${t('ui_held_in_stores')}</div></div>
      <span class="pill ${d.supplies[k] > 0 ? 'good' : 'bad'}">${d.supplies[k] || 0}</span></div>`).join('')}
    ${d.canRenew ? `<div class="actions"><button class="wood-btn" data-act="renew">${t('ui_extend_lease', d.leaseHours, d.leasePrice)}</button></div>` : ''}
  `;
}

function renderCrew(d) {
  const el = document.getElementById('tab-crew');
  if (!d.workers.length) { el.innerHTML = `<div class="empty">${t('ui_no_miners')}</div>`; return; }
  el.innerHTML = d.workers.map(w => {
    const st = [t('status_' + w.status), STATUS[w.status] || 'warn'];
    return `<div class="row"><div class="badge-icon">&#x26CF;</div>
      <div class="grow"><div class="name">${esc(w.name)}</div><div class="desc">${t('ui_skill_value', Number(w.skill).toFixed(2))} &middot; ${t('ui_wage_shift', w.wage)}</div>
        <div class="stats"><span>${t('ui_food')}</span>${bar(w.food)}<span>${t('ui_water')}</span>${bar(w.water)}<span>${t('ui_pickaxe')}</span>${bar(w.pickaxe)}</div>
      </div>
      <div style="display:flex;flex-direction:column;gap:6px;align-items:flex-end">
        <span class="pill ${st[1]}">${st[0]}</span>
        <button class="wood-btn muted" data-act="fire" data-id="${w.id}">${t('ui_dismiss')}</button>
      </div></div>`;
  }).join('');
}

function renderHire(d) {
  const full = d.workers.length >= d.maxWorkers;
  const el = document.getElementById('tab-hire');
  const head = `<div class="desc" style="text-align:center">${t('ui_new_faces', countdown(d.candidateRefresh))}${full ? ` &mdash; ${t('ui_crew_full')}` : ''}</div>`;
  if (!d.candidates.length) { el.innerHTML = head + `<div class="empty">${t('ui_no_candidates')}</div>`; return; }
  el.innerHTML = head + d.candidates.map(c => `
    <div class="row"><div class="badge-icon">&#x1F464;</div>
      <div class="grow"><div class="name">${esc(c.name)}</div><div class="desc">${t('ui_skill_value', c.skill)} &middot; ${t('ui_wage_shift', c.wage)}</div>
        <div class="stats"><span>${t('ui_skill')}</span>${bar(c.skill * 10)}</div></div>
      <button class="wood-btn" data-act="hire" data-key="${esc(c.key)}" ${full ? 'disabled' : ''}>${t('ui_hire_cost', c.cost)}</button>
    </div>`).join('');
}

function renderSupplies(d) {
  document.getElementById('tab-supplies').innerHTML =
    `<div class="desc" style="text-align:center">${t('ui_supplies_help')}</div>` +
    ['bread', 'water', 'pickaxe'].map(k => `
    <div class="row">${itemIcon(d, d.supplyCfg[k].image, FALLBACK[k])}
      <div class="grow"><div class="name">${esc(d.supplyCfg[k].label)}</div><div class="desc">${t('ui_you_carry', d.inventory[k] || 0)} &middot; ${t('ui_in_stores', d.supplies[k] || 0)}</div></div>
      <input type="number" min="1" max="${d.inventory[k] || 0}" value="${Math.min(1, d.inventory[k] || 0)}" id="amt-${k}">
      <button class="wood-btn" data-act="deposit" data-key="${k}" ${(d.inventory[k] || 0) < 1 ? 'disabled' : ''}>${t('ui_deposit')}</button>
    </div>`).join('');
}

function renderStorage(d) {
  const el = document.getElementById('tab-storage');
  if (!d.storage.length) { el.innerHTML = `<div class="empty">${t('ui_storage_empty')}</div>`; return; }
  el.innerHTML = d.storage.map(s => `
    <div class="row">${itemIcon(d, s.image)}
      <div class="grow"><div class="name">${esc(s.label)}</div><div class="desc">${t('ui_in_storage', s.amount)}</div></div>
      <button class="wood-btn" data-act="collect" data-item="${esc(s.item)}">${t('ui_collect')}</button>
    </div>`).join('') + `<div class="actions"><button class="wood-btn" data-act="collect" data-item="__all">${t('ui_collect_all')}</button></div>`;
}

function render() {
  if (!state) return;
  receivedAt = Date.now();
  // don't wipe amounts the player has typed when the server reply re-renders
  const keep = {};
  document.querySelectorAll('.content input[id]').forEach(i => { keep[i.id] = i.value; });
  document.getElementById('mineLabel').textContent = state.label;
  renderOverview(state); renderCrew(state); renderHire(state); renderSupplies(state); renderStorage(state);
  for (const [id, v] of Object.entries(keep)) {
    const el = document.getElementById(id);
    if (el && v !== '') el.value = el.max !== '' ? Math.min(Number(v), Number(el.max)) : v;
  }
}

function setTab(t) {
  tab = t;
  document.querySelectorAll('.tab').forEach(b => b.classList.toggle('active', b.dataset.tab === t));
  document.querySelectorAll('.tab-page').forEach(p => p.classList.toggle('hidden', p.id !== `tab-${t}`));
}

const app = document.getElementById('app');
const isHidden = () => app.classList.contains('hidden');
function close() { if (isHidden()) return; app.classList.add('hidden'); post('close'); }

document.querySelectorAll('.tab').forEach(b => b.addEventListener('click', () => setTab(b.dataset.tab)));
document.getElementById('closeBtn').addEventListener('click', close);
const refreshBtn = document.getElementById('refreshBtn');
refreshBtn.addEventListener('click', () => {
  if (refreshBtn.disabled) return;
  refreshBtn.disabled = true; // throttle: each refresh is a server round trip
  setTimeout(() => { refreshBtn.disabled = false; }, 1500);
  post('refresh');
});
document.addEventListener('keydown', e => { if (e.key === 'Escape') close(); });

document.querySelector('.content').addEventListener('click', e => {
  const b = e.target.closest('[data-act]');
  if (!b || b.disabled) return;
  const act = b.dataset.act;
  b.disabled = true; // stop double clicks; the server reply re-renders the tab
  setTimeout(() => { b.disabled = false; }, 1000);
  if (act === 'hire') post('hire', { key: b.dataset.key });
  else if (act === 'fire') post('fire', { id: b.dataset.id });
  else if (act === 'collect') post('collect', { item: b.dataset.item });
  else if (act === 'renew') post('renew');
  else if (act === 'addWages' || act === 'withdrawWages') {
    const amt = parseInt(document.getElementById('amt-wages').value, 10);
    if (amt > 0) post(act, { amount: amt });
  }
  else if (act === 'deposit') {
    const amt = parseInt(document.getElementById(`amt-${b.dataset.key}`).value, 10);
    if (amt > 0) post('deposit', { key: b.dataset.key, amount: amt });
  }
});

// ---- draggable panel (position saved per client) ----
const panel = document.querySelector('.panel');
const header = document.querySelector('.header');
const POS_KEY = 'rsg-mining:ui-pos';
let drag = null;

function clampPos(x, y) {
  const maxX = window.innerWidth - panel.offsetWidth, maxY = window.innerHeight - panel.offsetHeight;
  return [Math.max(0, Math.min(x, maxX)), Math.max(0, Math.min(y, maxY))];
}
function applyPos(x, y) {
  [x, y] = clampPos(x, y);
  panel.classList.add('dragged');
  panel.style.left = x + 'px'; panel.style.top = y + 'px';
  return [x, y];
}
function loadPos() {
  try {
    const p = JSON.parse(localStorage.getItem(POS_KEY));
    if (p && typeof p.x === 'number') { applyPos(p.x * window.innerWidth, p.y * window.innerHeight); return; }
  } catch (e) {}
  resetPos(false);
}
function resetPos(clear = true) {
  panel.classList.remove('dragged'); panel.style.left = ''; panel.style.top = '';
  if (clear) { try { localStorage.removeItem(POS_KEY); } catch (e) {} }
}

header.addEventListener('mousedown', e => {
  if (e.button !== 0 || e.target.closest('button')) return;
  const r = panel.getBoundingClientRect();
  drag = { dx: e.clientX - r.left, dy: e.clientY - r.top };
  applyPos(r.left, r.top);
  panel.classList.add('dragging');
  e.preventDefault();
});
document.addEventListener('mousemove', e => {
  if (drag) applyPos(e.clientX - drag.dx, e.clientY - drag.dy);
});
document.addEventListener('mouseup', () => {
  if (!drag) return;
  drag = null; panel.classList.remove('dragging');
  const r = panel.getBoundingClientRect();
  // stored as screen fractions so it survives resolution changes
  try { localStorage.setItem(POS_KEY, JSON.stringify({ x: r.left / window.innerWidth, y: r.top / window.innerHeight })); } catch (e) {}
});
header.addEventListener('dblclick', e => { if (!e.target.closest('button')) resetPos(); });
window.addEventListener('resize', () => { if (panel.classList.contains('dragged')) applyPos(panel.offsetLeft, panel.offsetTop); });

window.addEventListener('message', e => {
  const m = e.data;
  if (m.action === 'open') {
    if (m.locales) { LOC = m.locales; applyStaticLocales(); }
    state = m.data; render(); setTab('overview');
    app.classList.remove('hidden'); loadPos();
  }
  else if (m.action === 'update') { state = m.data; render(); setTab(tab); }
  else if (m.action === 'close') { app.classList.add('hidden'); }
});
