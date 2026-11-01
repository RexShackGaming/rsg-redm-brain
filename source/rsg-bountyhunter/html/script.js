const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-bountyhunter';
const $ = id => document.getElementById(id);
const app = $('app');
let T = {};
let timerHandle = null;
let busy = false;

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

  const disabled = locked || hasContract;
  board.innerHTML = posters.map(p => `
    <div class="poster${disabled ? ' disabled' : ''}">
      <div class="wanted">${esc(t('ui_wanted'))}</div>
      <span class="pill tier-${p.tier}">${esc(p.tierLabel)}</span>
      <div class="name">${esc(p.name)}</div>
      <div class="crime">${esc(p.crime)}</div>
      <div class="rewards">
        <span class="pill">${esc(t('ui_reward_alive'))} $${p.rewardAlive}</span>
        <span class="pill">${esc(t('ui_reward_dead'))} $${p.rewardDead}</span>
      </div>
      <button class="wood-btn" data-id="${p.id}" ${disabled ? 'disabled' : ''}>${esc(t('ui_take_contract'))}</button>
    </div>`).join('');
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

function close() {
  app.classList.add('hidden');
  clearInterval(timerHandle);
}

window.addEventListener('message', ({ data }) => {
  if (data.action === 'open') {
    const d = data.data || {};
    T = d.strings || {};
    applyStrings();
    $('office').textContent = d.office || t('ui_dead_or_alive');
    renderStats(d.stats);
    renderActive(d.contract);
    renderBoard(d.posters || [], !d.canHunt, !!d.contract);
    renderLeaders(d.leaderboard || []);
    switchTab('board');
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
$('abandon').addEventListener('click', () => { if (!busy) { busy = true; post('abandon').then(() => { busy = false; }); } });
$('close').addEventListener('click', () => post('close'));
document.addEventListener('keydown', e => { if (e.key === 'Escape' && !app.classList.contains('hidden')) post('close'); });
