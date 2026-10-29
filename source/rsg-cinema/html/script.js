const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-cinema';
const $ = id => document.getElementById(id);
const post = (name, body = {}) => fetch(`https://${resource}/${name}`, {
  method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body)
});
let timer = null;

const fmt = s => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;

function render(d, t) {
  $('title').textContent = d.label;
  $('subtitle').textContent = t.subtitle;
  $('nowShowing').textContent = t.nowShowing;
  $('film').textContent = d.film;
  $('priceLabel').textContent = t.price;
  $('price').textContent = `$${Number(d.price).toFixed(2)}`;
  $('closeBtn').textContent = t.close;
  const buy = $('buy');
  buy.textContent = d.hasTicket ? t.owned : t.buy;
  buy.disabled = d.hasTicket || !d.salesOpen;
  let left = d.startsIn;
  const tick = () => {
    if (d.playing) { $('statusLabel').textContent = t.playing; $('status').textContent = ''; return; }
    $('statusLabel').textContent = d.salesOpen ? t.startsIn : t.soon;
    $('status').textContent = fmt(Math.max(0, left));
    left--;
  };
  clearInterval(timer); tick(); timer = setInterval(tick, 1000);
}

// ---------------- admin panel
let admText = {}, admTimer = null;
const closeDds = () => document.querySelectorAll('.dd.open').forEach(d => d.classList.remove('open'));

// place the menu on screen next to its dropdown; open upwards if there is no room below
function positionMenu(el, menu) {
  const r = el.getBoundingClientRect();
  menu.style.left = r.left + 'px';
  menu.style.width = r.width + 'px';
  menu.style.top = ''; menu.style.bottom = '';
  const below = window.innerHeight - r.bottom - 8, above = r.top - 8;
  const h = Math.min(menu.scrollHeight, 200);
  if (below >= h || below >= above) {
    menu.style.top = (r.bottom + 2) + 'px';
    menu.style.maxHeight = Math.min(200, below) + 'px';
  } else {
    menu.style.bottom = (window.innerHeight - r.top + 2) + 'px';
    menu.style.maxHeight = Math.min(200, above) + 'px';
  }
}

function setupDd(el, options, value, onChange) {
  el.dataset.value = value;
  el.innerHTML = '<span class="dd-value"></span><span class="dd-arrow">▾</span><div class="dd-menu"></div>';
  const menu = el.querySelector('.dd-menu');
  const show = () => { const o = options.find(o => String(o.value) === String(el.dataset.value)); el.querySelector('.dd-value').textContent = o ? o.label : ''; };
  options.forEach(o => {
    const opt = document.createElement('div');
    opt.className = 'dd-opt' + (String(o.value) === String(value) ? ' sel' : '');
    opt.textContent = o.label;
    opt.addEventListener('mousedown', e => {
      e.preventDefault(); e.stopPropagation();
      el.dataset.value = o.value;
      menu.querySelectorAll('.dd-opt').forEach(x => x.classList.remove('sel'));
      opt.classList.add('sel'); show(); el.classList.remove('open');
      if (onChange) onChange(o.value);
    });
    menu.appendChild(opt);
  });
  el.addEventListener('mousedown', e => {
    if (e.target.closest('.dd-menu')) return;
    const open = el.classList.contains('open'); closeDds();
    if (!open) { el.classList.add('open'); positionMenu(el, menu); }
  });
  show();
}
document.addEventListener('mousedown', e => { if (!e.target.closest('.dd')) closeDds(); });
$('admList').addEventListener('scroll', closeDds);
window.addEventListener('resize', closeDds);

const openPics = new Set();
const PIC_FIELDS = [
  { k: 'x', label: 'adm_pos_x', min: 0, max: 1 },
  { k: 'y', label: 'adm_pos_y', min: 0, max: 1 },
  { k: 'w', label: 'adm_width', min: 0.1, max: 2 },
  { k: 'h', label: 'adm_height', min: 0.1, max: 2 },
];

function buildPicture(el, c) {
  const t = admText, box = el.querySelector('.pic'), toggle = el.querySelector('.pic-toggle');
  const draw = Object.assign({ x: 0.5, y: 0.5, w: 1, h: 1 }, c.draw || {});
  toggle.textContent = `✦ ${t.adm_picture}`;
  if (openPics.has(c.id)) box.classList.remove('hidden');
  toggle.addEventListener('click', () => {
    box.classList.toggle('hidden');
    box.classList.contains('hidden') ? openPics.delete(c.id) : openPics.add(c.id);
  });
  let pending = null;
  const preview = () => { clearTimeout(pending); pending = setTimeout(() => post('previewDraw', { id: c.id, draw }), 30); };
  const inputs = {};
  PIC_FIELDS.forEach(f => {
    const row = document.createElement('div');
    row.className = 'pic-row';
    row.innerHTML = `<label></label><input type="range" step="0.005"><span class="val"></span>`;
    row.querySelector('label').textContent = t[f.label];
    const inp = row.querySelector('input'), val = row.querySelector('.val');
    inp.min = f.min; inp.max = f.max; inp.value = draw[f.k];
    val.textContent = Number(draw[f.k]).toFixed(3);
    inp.addEventListener('input', () => { draw[f.k] = Number(inp.value); val.textContent = draw[f.k].toFixed(3); preview(); });
    inputs[f.k] = { inp, val };
    box.appendChild(row);
  });
  const note = document.createElement('div'); note.className = 'pic-note'; note.textContent = t.adm_preview_note;
  const actions = document.createElement('div'); actions.className = 'pic-actions';
  actions.innerHTML = `<button class="wood-btn muted reset"></button><button class="wood-btn save"></button>`;
  actions.querySelector('.reset').textContent = t.adm_reset;
  actions.querySelector('.save').textContent = t.adm_save;
  actions.querySelector('.reset').addEventListener('click', () => {
    Object.assign(draw, { x: 0.5, y: 0.5, w: 1, h: 1 });
    PIC_FIELDS.forEach(f => { inputs[f.k].inp.value = draw[f.k]; inputs[f.k].val.textContent = draw[f.k].toFixed(3); });
    preview();
  });
  actions.querySelector('.save').addEventListener('click', () => post('saveDraw', { id: c.id, draw }));
  box.appendChild(note); box.appendChild(actions);
}

function renderAdmin(list) {
  const t = admText, wrap = $('admList');
  closeDds(); wrap.innerHTML = '';
  if (!list || !list.length) { wrap.innerHTML = `<div class="empty">${t.adm_empty}</div>`; return; }
  list.forEach(c => {
    const el = document.createElement('div');
    el.className = 'cin';
    el.innerHTML = `
      <div class="cin-head"><span class="badge-icon">✦</span>
        <div class="row-text"><div class="row-title"></div><div class="row-desc"></div></div>
        <span class="pill"></span></div>
      <div class="cin-meta"><span class="m1"></span><span class="m2"></span></div>
      <div class="cin-actions"><div class="dd"></div><button class="wood-btn act"></button></div>
      <button class="wood-btn muted pic-toggle"></button>
      <div class="pic hidden"></div>`;
    el.querySelector('.row-title').textContent = c.label;
    el.querySelector('.row-desc').textContent = `${t.adm_film}: ${c.film}`;
    const pill = el.querySelector('.pill');
    pill.textContent = c.playing ? t.adm_playing : t.adm_idle;
    if (c.playing) pill.classList.add('on');
    const m1 = el.querySelector('.m1'), m2 = el.querySelector('.m2');
    m2.textContent = c.playing && c.public ? t.adm_public : `${t.adm_tickets}: ${c.tickets}`;
    let secs = c.playing ? c.elapsed : c.startsIn;
    const tick = () => { m1.textContent = `${c.playing ? t.adm_running : t.adm_next_in} ${fmt(Math.max(0, secs))}`; secs += c.playing ? 1 : -1; };
    tick(); el._tick = tick;
    const dd = el.querySelector('.dd');
    let chosen = c.filmIndex;
    setupDd(dd, c.films.map(f => ({ value: f.index, label: f.label })), c.filmIndex, v => { chosen = v; });
    if (c.playing) dd.classList.add('disabled');
    const btn = el.querySelector('.act');
    btn.textContent = c.playing ? t.adm_stop : t.adm_start;
    if (!c.playing) btn.classList.remove('muted'); else btn.classList.add('muted');
    btn.addEventListener('click', async () => {
      btn.disabled = true;
      const res = await post('adminAction', { action: c.playing ? 'stop' : 'start', id: c.id, filmIndex: Number(chosen) });
      renderAdmin(await res.json());
    });
    buildPicture(el, c);
    wrap.appendChild(el);
  });
  clearInterval(admTimer);
  admTimer = setInterval(() => wrap.querySelectorAll('.cin').forEach(e => e._tick && e._tick()), 1000);
}

$('admRefresh').addEventListener('click', async () => renderAdmin(await (await post('adminRefresh')).json()));
$('admClose').addEventListener('click', () => post('close'));

window.addEventListener('message', ({ data }) => {
  if (data.action === 'open') { render(data.data, data.text); $('app').classList.remove('hidden'); }
  if (data.action === 'openAdmin') {
    admText = data.text;
    $('admTitle').textContent = admText.adm_title; $('admSubtitle').textContent = admText.adm_subtitle;
    $('admRefresh').title = admText.adm_refresh;
    renderAdmin(data.data); $('admin').classList.remove('hidden');
  }
  if (data.action === 'close') {
    clearInterval(timer); clearInterval(admTimer); closeDds();
    $('app').classList.add('hidden'); $('admin').classList.add('hidden');
  }
});
$('buy').addEventListener('click', () => { if ($('buy').disabled) return; $('buy').disabled = true; post('buy'); });
$('close').addEventListener('click', () => post('close'));
$('closeBtn').addEventListener('click', () => post('close'));
document.addEventListener('keydown', e => { if (e.key === 'Escape') post('close'); });

// ---------------- draggable admin panel (drag by the header, position remembered)
(() => {
  const panel = document.querySelector('.admin-panel');
  const handle = panel.querySelector('.panel-header');
  const KEY = 'rsg-cinema-admin-pos';
  const clamp = (x, y) => [
    Math.min(Math.max(0, x), window.innerWidth - panel.offsetWidth),
    Math.min(Math.max(0, y), window.innerHeight - 60),
  ];
  const place = (x, y) => { [x, y] = clamp(x, y); panel.classList.add('moved'); panel.style.left = x + 'px'; panel.style.top = y + 'px'; };
  try { const p = JSON.parse(localStorage.getItem(KEY)); if (p) place(p.x, p.y); } catch (e) {}

  let dx = 0, dy = 0, dragging = false;
  handle.addEventListener('mousedown', e => {
    if (e.button !== 0 || e.target.closest('button')) return;
    const r = panel.getBoundingClientRect();
    dx = e.clientX - r.left; dy = e.clientY - r.top; dragging = true;
    place(r.left, r.top); panel.classList.add('dragging'); e.preventDefault();
  });
  document.addEventListener('mousemove', e => { if (dragging) { closeDds(); place(e.clientX - dx, e.clientY - dy); } });
  document.addEventListener('mouseup', () => {
    if (!dragging) return;
    dragging = false; panel.classList.remove('dragging');
    try { localStorage.setItem(KEY, JSON.stringify({ x: parseFloat(panel.style.left), y: parseFloat(panel.style.top) })); } catch (e) {}
  });
  // double-click the header to reset to centre
  handle.addEventListener('dblclick', e => {
    if (e.target.closest('button')) return;
    panel.classList.remove('moved'); panel.style.left = panel.style.top = '';
    try { localStorage.removeItem(KEY); } catch (e) {}
  });
  window.addEventListener('resize', () => { if (panel.classList.contains('moved')) place(parseFloat(panel.style.left), parseFloat(panel.style.top)); });
})();

