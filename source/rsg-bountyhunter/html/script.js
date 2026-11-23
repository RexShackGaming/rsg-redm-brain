const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-bountyhunter';
const $ = id => document.getElementById(id);
const app = $('app');
let T = {};
let timerHandle = null;
let busy = false;
let abandonArmed = false;
let abandonTimer = null;

const post = (name, body = {}) => fetch(`https://${resource}/${name}`, {
  method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body)
}).then(r => r.json()).catch(() => ({}));

const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' }[c]));
const fmtTime = s => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
const t = key => T[key] || key;

function applyStrings() {
  document.querySelectorAll('[data-t]').forEach(el => { el.textContent = t(el.dataset.t); });
  document.querySelectorAll('[data-t-title]').forEach(el => { el.title = t(el.dataset.tTitle); });
}

function renderStats(st = {}) {
  $('st-completed').textContent = st.completed || 0;
  $('st-alive').textContent = st.alive || 0;
  $('st-dead').textContent = st.dead || 0;
  $('st-earned').textContent = `$${st.earned || 0}`;
}

function renderActive(c) {
  clearInterval(timerHandle);
  $('active').classList.toggle('hidden', !c);
  if (!c) return;
  $('ac-name').textContent = c.name;
  $('ac-crime').textContent = c.crime;
  $('ac-reward').textContent = `${t('ui_reward_alive')} $${c.rewardAlive} · ${t('ui_reward_dead')} $${c.rewardDead}`;
  let left = c.remaining;
  const tick = () => { $('ac-timer').textContent = fmtTime(Math.max(0, left--)); };
  tick();
  timerHandle = setInterval(tick, 1000);
}

function renderBoard(posters, locked, hasContract) {
  const board = $('board');
  $('locked').classList.toggle('hidden', !locked);
  if (!posters.length) { board.innerHTML = `<div class="empty">${esc(t('ui_no_posters'))}</div>`; return; }

  board.innerHTML = posters.map(p => {
    const disabled = locked || hasContract || p.locked;
    const cond = p.condition === 'alive' ? 'ui_alive_only' : p.condition === 'dead' ? 'ui_dead_only' : null;
    const aliveR = p.condition === 'dead' ? '' : `<span class="pill">${esc(t('ui_reward_alive'))} $${p.rewardAlive}</span>`;
    const deadR = p.condition === 'alive' ? '' : `<span class="pill">${esc(t('ui_reward_dead'))} $${p.rewardDead}</span>`;
    return `
    <div class="poster${disabled ? ' disabled' : ''}">
      <div class="wanted">${esc(t('ui_wanted'))}</div>
      <span class="pill tier-${p.tier}">${esc(p.tierLabel)}</span>
      ${cond ? `<span class="pill cond">${esc(t(cond))}</span>` : ''}
      <div class="name">${esc(p.name)}</div>
      <div class="crime">${esc(p.crime)}</div>
      <div class="rewards">
        ${aliveR}${deadR}
      </div>
      ${p.locked ? `<div class="lvl-lock">${esc(t('ui_requires_level'))} ${p.minLevel}</div>` : ''}
      <button class="wood-btn" data-id="${p.id}" ${disabled ? 'disabled' : ''}>${esc(t('ui_take_contract'))}</button>
    </div>`;
  }).join('');
}

function renderProg(level, streak) {
  const parts = [];
  if (level) parts.push(`${esc(t('ui_level'))} ${level}`);
  if (streak) parts.push(`${esc(t('ui_streak'))} ${streak}`);
  $('prog').innerHTML = parts.map(x => `<span class="pill">${x}</span>`).join('');
  $('prog').classList.toggle('hidden', !parts.length);
}

function renderLeaders(rows) {
  const list = $('leaders');
  if (!rows.length) { list.innerHTML = `<div class="empty">${esc(t('ui_no_hunters'))}</div>`; return; }
  list.innerHTML = rows.map((r, i) => `
    <div class="row">
      <span class="badge-icon">${i + 1}</span>
      <div class="row-text"><div class="row-title">${esc(r.name)}</div><div class="row-desc">${r.completed} ${esc(t('ui_bounties_count'))}</div></div>
      <span class="pill">$${r.earned}</span>
    </div>`).join('');
}

function switchTab(tab) {
  document.querySelectorAll('.tab').forEach(el => el.classList.toggle('active', el.dataset.tab === tab));
  $('board').classList.toggle('hidden', tab !== 'board');
  $('leaders').classList.toggle('hidden', tab !== 'leaders');
}

// the abandon button needs a second click within 3 seconds (a misclick costs a cooldown)
function resetAbandon() {
  abandonArmed = false;
  clearTimeout(abandonTimer);
  const btn = $('abandon');
  btn.classList.remove('armed');
  btn.textContent = t('ui_abandon');
}

function close() {
  app.classList.add('hidden');
  clearInterval(timerHandle);
  resetAbandon();
  busy = false;
}

window.addEventListener('message', ({ data }) => {
  if (data.action === 'open') {
    const d = data.data || {};
    T = d.strings || {};
    applyStrings();
    $('office').textContent = d.office || t('ui_dead_or_alive');
    renderStats(d.stats);
    renderActive(d.contract);
    renderProg(d.level, d.streak);
    renderBoard(d.posters || [], !d.canHunt, !!d.contract);
    renderLeaders(d.leaderboard || []);
    switchTab('board');
    resetAbandon();
    busy = false;
    app.classList.remove('hidden');
  }
  if (data.action === 'close') close();
});

// one delegated handler for every poster button
$('board').addEventListener('click', async e => {
  const btn = e.target.closest('button[data-id]');
  if (!btn || btn.disabled || busy) return;
  busy = true;
  btn.disabled = true;
  const res = await post('accept', { id: Number(btn.dataset.id) });
  busy = false;
  if (!res.ok) btn.disabled = false;
});

document.querySelectorAll('.tab').forEach(el => el.addEventListener('click', () => switchTab(el.dataset.tab)));
$('abandon').addEventListener('click', () => {
  if (busy) return;
  if (!abandonArmed) {
    abandonArmed = true;
    $('abandon').classList.add('armed');
    $('abandon').textContent = t('ui_confirm_abandon');
    abandonTimer = setTimeout(resetAbandon, 3000);
    return;
  }
  resetAbandon();
  busy = true;
  post('abandon').then(() => { busy = false; });
});
$('close').addEventListener('click', () => post('close'));
document.addEventListener('keydown', e => { if (e.key === 'Escape' && !app.classList.contains('hidden')) post('close'); });
