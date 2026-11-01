// rsg-stables: horse actions NUI
(function () {
  const res = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'rsg-stables';
  const post = (name, data) => fetch(`https://${res}/${name}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data || {}),
  }).then((r) => r.json()).catch(() => ({}));

  const $ = (id) => document.getElementById(id);
  const modal = $('actionsModal'), list = $('actionsList');
  let S = {}, actions = [], current = null, open = false;

  function row(id, glyph, title, desc, cls, pill) {
    const el = document.createElement('div');
    el.className = 'action-row' + (cls ? ' ' + cls : '');
    el.innerHTML = '<div class="action-badge"></div><div class="action-info"><div class="action-title"></div><div class="action-desc"></div></div>';
    el.querySelector('.action-badge').textContent = glyph || '\u2726';
    el.querySelector('.action-title').textContent = title;
    el.querySelector('.action-desc').textContent = desc;
    if (pill) { const p = document.createElement('span'); p.className = 'action-pill'; p.textContent = pill; el.appendChild(p); }
    if (cls !== 'active') el.addEventListener('click', () => post('actionsSelect', { id }));
    list.appendChild(el);
  }

  function render() {
    list.innerHTML = '';
    if (current) row('stop', '\u25A0', S.stop, S.stop_desc, 'stop');
    actions.forEach((a) => row(a.id, a.glyph, a.label, a.desc, current === a.id ? 'active' : '', current === a.id ? S.active : null));
  }

  // ---- drag the panel by its title; position remembered per player ----
  const card = modal.querySelector('.actions-card');
  const handle = $('actionsTitle');
  let pos = { x: 0, y: 0 };
  try { pos = JSON.parse(localStorage.getItem('rsgStablesActionsPos')) || pos; } catch (e) {}
  function applyPos() {
    // keep at least part of the panel on screen
    const r = card.getBoundingClientRect();
    const baseX = r.left - pos.x, baseY = r.top - pos.y;
    pos.x = Math.min(Math.max(pos.x, -baseX), window.innerWidth - baseX - r.width);
    pos.y = Math.min(Math.max(pos.y, -baseY), window.innerHeight - baseY - r.height);
    card.style.transform = `translate(${pos.x}px, ${pos.y}px)`;
  }
  let drag = null;
  handle.addEventListener('mousedown', (e) => {
    if (e.button !== 0) return;
    drag = { sx: e.clientX - pos.x, sy: e.clientY - pos.y };
    e.preventDefault();
  });
  document.addEventListener('mousemove', (e) => {
    if (!drag) return;
    pos.x = e.clientX - drag.sx; pos.y = e.clientY - drag.sy;
    applyPos();
  });
  document.addEventListener('mouseup', () => {
    if (!drag) return;
    drag = null;
    try { localStorage.setItem('rsgStablesActionsPos', JSON.stringify(pos)); } catch (e) {}
  });
  handle.addEventListener('dblclick', () => { pos = { x: 0, y: 0 }; applyPos();
    try { localStorage.removeItem('rsgStablesActionsPos'); } catch (e) {} });

  function close() { if (!open) return; open = false; modal.classList.add('hidden'); post('actionsClose'); }
  $('actionsCloseBtn').addEventListener('click', close);
  document.addEventListener('keydown', (e) => { if (open && (e.key === 'Escape' || e.key === 'Backspace')) close(); });

  window.addEventListener('message', (event) => {
    const d = event.data;
    if (!d) return;
    if (d.action === 'actionsOpen') {
      S = d.strings || {}; actions = d.actions || []; current = d.current || null;
      $('actionsTitle').textContent = S.title || '';
      $('actionsHorse').textContent = d.horseName || '';
      $('actionsCloseBtn').textContent = S.close || 'Close';
      open = true; modal.classList.remove('hidden'); render(); applyPos();
    } else if (d.action === 'actionsClose') {
      open = false; modal.classList.add('hidden');
    }
  });
})();
