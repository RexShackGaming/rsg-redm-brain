const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-drugs';
let state = null;
let tickEnd = 0; // client timestamp (ms) when the next shift finishes
let tickTimer = null;
const $ = (s) => document.querySelector(s);
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
// Lua tables keyed 1..n arrive as 0-based JSON arrays
const skillLabel = (n) => { const sk = state.config.skills; const v = Array.isArray(sk) ? sk[n - 1] : sk[n]; return v ? v.label : t('ui_skill', n); };
const IMG_PATH = 'nui://rsg-inventory/html/images/';
// item image inside the round badge, falls back to the letter if the png is missing
const itemIcon = (item, letter) => item
  ? `<div class="badge-icon img"><img src="${IMG_PATH}${esc(item)}.png" alt="" onerror="this.parentElement.classList.remove('img');this.parentElement.textContent='${letter}'"></div>`
  : `<div class="badge-icon">${letter}</div>`;
const itemName = (k) => state.config.items ? state.config.items[k] : null;
const packing = () => state.config.packing;
const money = (n) => '$' + Number(n).toFixed(2);
// locales come from locales/*.json via lib.getLocales(); %s placeholders filled in order, %% = literal %
let LOCALE = {};
const t = (key, ...args) => { let i = 0; return String(LOCALE[key] ?? key).replace(/%%|%s/g, (m) => m === '%%' ? '%' : String(args[i++] ?? '')); };
const applyStatic = () => document.querySelectorAll('[data-l]').forEach((el) => { el.textContent = t(el.dataset.l); });
const slow = (e) => e.hunger < 25 || e.thirst < 25 || e.unpaid > 0;
const workRate = (list) => list.filter((e) => !e.strike).reduce((a, e) => a + e.rate * (slow(e) ? 0.5 : 1), 0);

function post(name, body) {
  return fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body || {}) }).then((r) => r.json()).catch(() => null);
}
async function act(action, data) {
  const res = await post('action', { action, data });
  if (res) { state = res; syncTick(res); render(); }
}
function barClass(v) { return v > 50 ? 'stat-good' : v > 20 ? 'stat-warn' : 'stat-bad'; }
function bar(label, v) {
  return `<div><div class="bar-l">${label} ${Math.round(v)}%</div><div class="track"><div class="fill ${barClass(v)}" style="width:${Math.max(0, Math.min(100, v))}%"></div></div></div>`;
}
function status(e) {
  if (e.strike) return `<span class="pill strike">${t('ui_on_strike')}</span>`;
  if (slow(e)) return `<span class="pill slow">${t('ui_slacking')}</span>`;
  return `<span class="pill work">${t('ui_working')}</span>`;
}

// progress towards the next whole unit for a role (lab.progress is fractional carry-over)
function prodBar(role, from) {
  const { lab } = state;
  const p = ((lab.progress && lab.progress[role]) || 0) % 1;
  const crew = lab.employees.filter((e) => e.role === role);
  const active = crew.some((e) => !e.strike);
  const roleLabel = state.config.roles[role].label;
  let note = t('ui_to_next', Math.round(p * 100));
  if (!crew.length) note = t('ui_no_role', roleLabel);
  else if (!active) note = t('ui_role_strike', roleLabel);
  else if (lab.stock[from] < 1) note = from === 'raw' ? t('ui_wait_raw') : t('ui_wait_dried');
  return `<div class="prod"><div class="bar-l">${note}</div><div class="track"><div class="fill ${active && lab.stock[from] > 0 ? 'prod-fill' : 'stat-bad'}" style="width:${active ? Math.round(p * 100) : 0}%"></div></div></div>`;
}
function updateShift() {
  const fill = $('#shift-fill'), left = $('#shift-left');
  if (!fill || !state) return;
  const total = state.config.tick * 1000;
  const rem = Math.max(0, tickEnd - Date.now());
  fill.style.width = (100 - (rem / total) * 100) + '%';
  left.textContent = Math.ceil(rem / 1000) + 's';
  if (rem <= 0) tickEnd = Date.now() + total; // rolls over until the server refresh lands
}
function syncTick(d) {
  if (d && d.nextTickIn !== undefined) tickEnd = Date.now() + d.nextTickIn * 1000;
  if (!tickTimer) tickTimer = setInterval(updateShift, 250);
}

function packRow(prod, letter) {
  const { lab } = state;
  const pk = packing()[prod];
  const crew = lab.employees.filter((e) => e.role === 'packer' && (e.pack || 'bag') === prod);
  const work = workRate(crew);
  const p = ((lab.progress && lab.progress[prod]) || 0) % 1;
  const ok = work > 0 && lab.stock.processed >= pk.uses && !(prod === 'brick' && state.brickLock);
  let note = t('ui_to_next', Math.round(p * 100));
  const locked = prod === 'brick' && state.brickLock;
  if (locked) note = t('ui_brick_locked', state.brickLock);
  else if (!crew.length) note = t('ui_no_packer', pk.label.toLowerCase());
  else if (work <= 0) note = t('ui_packers_strike');
  else if (lab.stock.processed < pk.uses) note = t('ui_wait_processed', pk.uses);
  return `<div class="row">${itemIcon(itemName(prod), letter)}<div class="grow"><div class="name">${esc(t('ui_packing', pk.label))}</div>
    <div class="desc">${t('ui_pack_desc', pk.uses, (work / pk.work).toFixed(2))}</div>
    <div class="prod"><div class="bar-l">${note}</div><div class="track"><div class="fill ${ok ? 'prod-fill' : 'stat-bad'}" style="width:${ok ? Math.round(p * 100) : 0}%"></div></div></div></div></div>`;
}

function repBlock() {
  const x = state.xp;
  if (!x) return '';
  const pct = x.to ? Math.round(((x.xp - x.from) / (x.to - x.from)) * 100) : 100;
  const prog = x.to ? t('ui_xp', x.xp, x.to) : t('ui_xp_max', x.xp);
  return `<div class="label">${t('ui_rep')}</div>
    <div class="row"><div class="badge-icon">${x.level}</div><div class="grow"><div class="name">${esc(x.label)}</div>
    <div class="desc">${t('ui_level', x.level)} · ${prog}</div>
    <div class="prod"><div class="track"><div class="fill prod-fill" style="width:${pct}%"></div></div></div></div></div>`;
}

function renderOverview() {
  const { lab, config } = state;
  const emps = lab.employees;
  const working = emps.filter((e) => !e.strike).length;
  const rate = (role) => workRate(emps.filter((e) => e.role === role));
  const wages = emps.reduce((a, e) => a + e.wage, 0);
  const ticksLeft = wages > 0 ? Math.floor(lab.payroll / wages) : '∞';
  const eff = emps.length ? Math.round((working / emps.length) * 100) : 0;
  $('#tab-overview').innerHTML = repBlock() + `
    <div class="label">${t('ui_stock')}</div>
    <div class="grid">
      <div class="stat">${itemIcon(itemName('raw'), 'W')}<div class="v">${lab.stock.raw}</div><div class="k">${t('ui_fresh')}</div></div>
      <div class="stat">${itemIcon(itemName('dried'), 'D')}<div class="v">${lab.stock.dried}</div><div class="k">${t('ui_dried')}</div></div>
      <div class="stat">${itemIcon(itemName('processed'), 'P')}<div class="v">${lab.stock.processed}</div><div class="k">${t('ui_processed')}</div></div>
    </div>
    <div class="grid" style="margin-top:8px">
      <div class="stat">${itemIcon(itemName('brick'), 'B')}<div class="v">${lab.stock.brick || 0}</div><div class="k">${t('ui_bricks')}</div></div>
      <div class="stat">${itemIcon(itemName('bag'), 'b')}<div class="v">${lab.stock.bag || 0}</div><div class="k">${t('ui_bags')}</div></div>
      <div class="stat">${itemIcon(itemName('seed'), 'S')}<div class="v">${lab.stock.seed || 0}</div><div class="k">${t('ui_seeds')}</div></div>
    </div>
    <div class="label">${t('ui_per_shift', config.tick)}</div>
    <div class="shift"><div class="bar-l">${t('ui_next_shift')} <span id="shift-left">--</span></div><div class="track"><div class="fill shift-fill" id="shift-fill"></div></div></div>
    <div class="row">${itemIcon(itemName('dried'), 'D')}<div class="grow"><div class="name">${t('ui_drying')}</div><div class="desc">${t('ui_drying_desc', rate('dryer').toFixed(1))} · ${t('ui_seed_chance', state.config.seedChance || 0)}</div>${prodBar('dryer', 'raw')}</div></div>
    <div class="row">${itemIcon(itemName('processed'), 'P')}<div class="grow"><div class="name">${t('ui_processing')}</div><div class="desc">${t('ui_processing_desc', rate('processor').toFixed(1))}</div>${prodBar('processor', 'dried')}</div></div>
    ${packRow('bag', 'b')}${packRow('brick', 'B')}
    <div class="label">${t('ui_crew')}</div>
    <div class="grid">
      <div class="stat"><div class="v">${working}/${emps.length}</div><div class="k">${t('ui_working')}</div></div>
      <div class="stat"><div class="v">${eff}%</div><div class="k">${t('ui_efficiency')}</div></div>
      <div class="stat"><div class="v">${money(lab.payroll)}</div><div class="k">${t('ui_payroll_shifts', ticksLeft)}</div></div>
    </div>
    <div class="grid" style="margin-top:8px;grid-template-columns:1fr 1fr">
      <div class="stat"><div class="v">${lab.pantry.food}</div><div class="k">${t('ui_meals')}</div></div>
      <div class="stat"><div class="v">${lab.pantry.water}</div><div class="k">${t('ui_drinks')}</div></div>
    </div>`;
}

function renderCrew() {
  const { lab, config } = state;
  if (!lab.employees.length) { $('#tab-crew').innerHTML = `<div class="empty">${t('ui_no_workers')}</div>`; return; }
  $('#tab-crew').innerHTML = `<div class="label">${t('ui_workers', lab.employees.length, config.maxEmployees)}</div>` + lab.employees.map((e) => `
    <div class="row">
      <div class="badge-icon">${e.skill}</div>
      <div class="grow">
        <div class="name">${esc(e.name)}</div>
        <div class="desc">${config.roles[e.role].label} · ${skillLabel(e.skill)} · ${t('ui_per_shift_wage', money(e.wage))}${e.unpaid ? ' · ' + t('ui_owed', e.unpaid) : ''}</div>
        <div class="bars">${bar(t('ui_food'), e.hunger)}${bar(t('ui_water'), e.thirst)}</div>
      </div>
      ${e.role === 'packer' ? `<div class="seg">${Object.keys(packing()).map((k) => `<button class="seg-btn ${(e.pack || 'bag') === k ? 'on' : ''}" data-pack="${e.id}" data-prod="${k}" ${k === 'brick' && state.brickLock && (e.pack || 'bag') !== k ? 'disabled title="' + esc(t('ui_brick_locked', state.brickLock)) + '"' : ''}>${esc(packing()[k].label)}${k === 'brick' && state.brickLock ? ' 🔒' : ''}</button>`).join('')}</div>` : ''}
      ${status(e)}
      <button class="btn muted" data-fire="${e.id}">${t('ui_fire')}</button>
    </div>`).join('');
}

function renderHire() {
  const { lab, candidates, config } = state;
  const full = lab.employees.length >= config.maxEmployees;
  $('#tab-hire').innerHTML = `<div class="label">${t('ui_hire_header', money(config.hireFee), lab.employees.length, config.maxEmployees)}</div><div class="hire-grid">` + candidates.map((c, i) => `
    <div class="row">
      <div class="badge-icon">${c.skill}</div>
      <div class="grow">
        <div class="name">${esc(c.name)}</div>
        <div class="desc">${config.roles[c.role].label} · ${skillLabel(c.skill)} · ${t('ui_cand_desc', c.rate, money(c.wage))}</div>
      </div>
      <span class="pill">${config.roles[c.role].label}</span>
      <button class="btn" data-hire="${i + 1}" data-name="${esc(c.name)}" ${full ? 'disabled' : ''}>${t('ui_hire')}</button>
    </div>`).join('') + '</div>';
}

function supplyRow(icon, img, title, desc, kind, item, max, btn) {
  return `<div class="row">${itemIcon(img, icon)}<div class="grow"><div class="name">${esc(title)}</div><div class="desc">${esc(desc)}</div></div>
    <input class="qty" type="number" min="1" max="${max}" value="${Math.min(1, max)}" data-qty>
    <button class="btn muted" data-max="${max}" ${max < 1 ? 'disabled' : ''}>${t('ui_max')}</button>
    <button class="btn" data-kind="${kind}" data-item="${item || ''}" ${max < 1 ? 'disabled' : ''}>${btn}</button></div>`;
}

function renderSupplies() {
  const { lab, supplies } = state;
  const s = supplies || { raw: 0, food: [], water: [] };
  let html = `<div class="label">${t('ui_hand_over')}</div>`;
  html += supplyRow('W', itemName('raw'), t('ui_fresh'), t('ui_carry', s.raw), 'raw', '', s.raw, t('ui_deposit'));
  s.food.forEach((f) => { html += supplyRow('F', f.item, f.label, t('ui_meal_each', f.count, f.value), 'food', f.item, f.count, t('ui_give')); });
  s.water.forEach((w) => { html += supplyRow('H', w.item, w.label, t('ui_drink_each', w.count, w.value), 'water', w.item, w.count, t('ui_give')); });
  if (!s.food.length && !s.water.length) html += `<div class="empty">${t('ui_no_food')}</div>`;
  html += `<div class="label">${t('ui_payroll')}</div>`;
  html += `<div class="row"><div class="badge-icon">$</div><div class="grow"><div class="name">${t('ui_wage_chest')}</div><div class="desc">${t('ui_balance', money(lab.payroll))}</div></div>
    <input class="qty" type="number" min="1" value="10" data-qty><button class="btn" data-kind="payroll">${t('ui_add_cash')}</button></div>`;
  html += `<div class="label">${t('ui_collect')}</div>`;
  const ready = (k) => lab.stock[k] || 0;
  [['D', 'dried', 'ui_dried_weed'], ['P', 'processed', 'ui_processed_weed'], ['B', 'brick', 'ui_weed_bricks'], ['b', 'bag', 'ui_weed_bags'], ['S', 'seed', 'ui_weed_seeds']].forEach(([l, k, key]) => {
    html += supplyRow(l, itemName(k), t(key), t('ui_ready', ready(k)), k, '', ready(k), t('ui_collect'));
  });
  $('#tab-supplies').innerHTML = html;
}

function render(keepInputs) {
  if (!state) return;
  renderOverview(); renderCrew(); renderHire();
  // a background shift refresh must not wipe a quantity the player is typing
  if (!(keepInputs && document.activeElement && document.activeElement.matches('[data-qty]'))) renderSupplies();
  updateShift();
}
function setTab(t) {
  document.querySelectorAll('.tab').forEach((b) => b.classList.toggle('active', b.dataset.tab === t));
  document.querySelectorAll('.content').forEach((v) => v.classList.toggle('hidden', v.id !== 'view-' + t));
}

document.addEventListener('click', (e) => {
  const t = e.target;
  if (t.classList.contains('tab')) return setTab(t.dataset.tab);
  if (t.dataset.pack) { if (t.classList.contains('on')) return; return act('assign', { id: Number(t.dataset.pack), pack: t.dataset.prod }); }
  if (t.dataset.fire) return act('fire', { id: Number(t.dataset.fire) });
  if (t.dataset.hire) return act('hire', { index: Number(t.dataset.hire), name: t.dataset.name });
  if (t.dataset.max !== undefined) {
    // max = everything the player carries (or everything ready to collect); do it in one click
    const go = t.parentElement.querySelector('[data-kind]');
    t.parentElement.querySelector('[data-qty]').value = t.dataset.max;
    if (go && !go.disabled) go.click();
    return;
  }
  if (t.dataset.kind) {
    const qty = Number(t.parentElement.querySelector('[data-qty]')?.value || 0);
    if (!(qty > 0)) return;
    const k = t.dataset.kind;
    if (k === 'payroll') return act('payroll', { amount: qty });
    if (k === 'dried' || k === 'processed' || k === 'brick' || k === 'bag' || k === 'seed') return act('withdraw', { kind: k, amount: qty });
    return act('deposit', { kind: k, item: t.dataset.item, amount: qty });
  }
});
$('#close').addEventListener('click', () => post('close'));
document.addEventListener('keyup', (e) => { if (e.key === 'Escape' && !$('#app').classList.contains('hidden')) post('close'); });

window.addEventListener('message', ({ data }) => {
  if (data.action === 'open') { if (data.locale) { LOCALE = data.locale; applyStatic(); } state = data.data; syncTick(state); $('#app').classList.remove('hidden'); setTab('operation'); render(); }
  else if (data.action === 'update' && state) { const sup = state.supplies; state = data.data; state.supplies = sup; syncTick(state); render(true); }
  else if (data.action === 'close') { $('#app').classList.add('hidden'); clearInterval(tickTimer); tickTimer = null; }
});
