const app = document.getElementById('app');
const list = document.getElementById('list');
let state = { animals: [], pelts: [], cash: 0 };
let L = {};
let tab = 'maps';
let busy = false;

const post = (name, body = {}) =>
  fetch(`https://${GetParentResourceName()}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });

const esc = (s) => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

// one request at a time: stops double-buying on fast clicks while the server answers
async function action(name, body) {
  if (busy) return;
  busy = true; list.classList.add('busy');
  try { await post(name, body); } finally { busy = false; list.classList.remove('busy'); }
}

function fmtTime(sec) {
  const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60);
  if (h > 0) return `${h}h ${m}m`;
  return m > 0 ? `${m}m` : `${Math.floor(sec % 60)}s`;
}

function render() {
  document.getElementById('cash').textContent = Number(state.cash || 0).toFixed(2);
  list.innerHTML = '';
  if (tab === 'maps') {
    state.animals.forEach(a => {
      const cd = a.cooldown > 0;
      const locked = (a.minXP || 0) > (state.xp || 0);
      const row = document.createElement('div');
      row.className = 'row' + (cd || locked ? ' disabled' : '');
      row.innerHTML = `
        <div class="badge-icon">&#10022;</div>
        <div class="row-text">
          <div class="row-title">${esc(a.label)}</div>
          <div class="row-desc">${locked ? `${esc(L.needxp)} ${a.minXP} ${esc(L.xp)} (${state.xp || 0})` : cd ? `${esc(L.cooldown)} ${fmtTime(a.cooldown)}` : esc(a.description)}</div>
        </div>
        <span class="pill">$${a.price}</span>`;
      if (!cd && !locked) row.addEventListener('click', () => action('buy', { key: a.key }));
      list.appendChild(row);
    });
  } else if (tab === 'trophies') {
    const t = state.trophies || [];
    t.forEach(r => {
      const row = document.createElement('div');
      row.className = 'row static';
      const first = r.first ? `${esc(L.first)}: ${esc(r.first)}` : `${esc(L.first)}: ${esc(L.noneyet)}`;
      const fast = r.fastest ? ` &middot; ${esc(L.fastest)}: ${esc(r.fastest)} (${fmtTime(r.seconds || 0)})` : '';
      row.innerHTML = `
        <div class="badge-icon">${r.kills > 0 ? '&#10003;' : '&#10022;'}</div>
        <div class="row-text">
          <div class="row-title">${esc(r.label)}</div>
          <div class="row-desc">${first}${fast}</div>
        </div>
        <span class="pill" title="${esc(L.perfect)}">${esc(L.yours)} ${r.kills}${r.perfect ? ` &middot; &#9733;${r.perfect}` : ''}</span>`;
      list.appendChild(row);
    });
  } else {
    if (!state.pelts.length) {
      list.innerHTML = `<div class="empty">${esc(L.nothing)}</div>`;
      return;
    }
    state.pelts.forEach(p => {
      const row = document.createElement('div');
      row.className = 'row';
      row.innerHTML = `
        <div class="badge-icon">x${p.count}</div>
        <div class="row-text">
          <div class="row-title">${esc(p.label)}</div>
          <div class="row-desc">$${p.price} ${esc(L.each)} &middot; $${(p.price * p.count).toFixed(2)}</div>
        </div>
        <button class="wood-btn">${esc(L.sellall)}</button>`;
      row.querySelector('button').addEventListener('click', (e) => { e.stopPropagation(); action('sell', { item: p.name }); });
      list.appendChild(row);
    });
  }
}

function setTab(t) {
  tab = t;
  document.querySelectorAll('.tab').forEach(b => b.classList.toggle('active', b.dataset.tab === t));
  render();
}

document.querySelectorAll('.tab').forEach(b => b.addEventListener('click', () => setTab(b.dataset.tab)));
document.getElementById('close').addEventListener('click', () => post('close'));
document.addEventListener('keyup', e => { if (e.key === 'Escape' && !app.classList.contains('hidden')) post('close'); });

window.addEventListener('message', ({ data }) => {
  if (data.action === 'open') {
    state = data.data; L = data.locale || {};
    document.getElementById('ui-title').textContent = L.title;
    document.getElementById('ui-subtitle').textContent = L.subtitle;
    document.getElementById('tab-maps').textContent = L.maps;
    document.getElementById('tab-sell').textContent = L.sell;
    document.getElementById('tab-trophies').textContent = L.trophies;
    document.getElementById('tab-trophies').classList.toggle('hidden', !state.trophies);
    document.getElementById('ui-cash').textContent = L.cash;
    app.classList.remove('hidden');
    setTab('maps');
  } else if (data.action === 'refresh') {
    state = data.data; render();
  } else if (data.action === 'close') {
    app.classList.add('hidden');
  }
});
