// Addiction status panel (/addiction). Shares the rsg-drugs NUI page.
(() => {
  const RES_A = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-drugs';
  const root = document.getElementById('addiction');
  const list = document.getElementById('ad-list');
  const statusEl = document.getElementById('ad-status');
  let labels = null, stageLabel = null;

  const post = (name, body = {}) => fetch(`https://${RES_A}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(body) }).catch(() => {});
  const cls = (v) => v >= 60 ? 'ad-bad' : v >= 30 ? 'ad-warn' : 'ad-good';
  const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

  function render(data) {
    if (!labels) return;
    const subs = (data && data.subs) || {};
    const rehab = (data && data.rehab) || 0;
    if (rehab > 0) { statusEl.textContent = labels.rehab.replace('%s', Math.ceil(rehab / 60)); statusEl.classList.remove('hidden'); }
    else if (stageLabel) { statusEl.textContent = stageLabel; statusEl.classList.remove('hidden'); }
    else statusEl.classList.add('hidden');
    list.innerHTML = Object.keys(labels.subs).map((key) => {
      const meta = labels.subs[key];
      const s = subs[key] || { level: 0, craving: 0 };
      const hooked = s.level >= meta.threshold;
      return `<div class="ad-row"><div class="ad-icon">${esc(meta.label.charAt(0))}</div><div class="ad-text">
        <div class="ad-head"><span class="ad-name">${esc(meta.label)}</span><span class="ad-pill ${hooked ? 'bad' : ''}">${esc(hooked ? labels.hooked : labels.clean)}</span></div>
        <div class="ad-label">${esc(labels.level)}</div><div class="ad-bar"><div class="ad-fill ${cls(s.level)}" style="width:${Math.round(s.level)}%"></div></div>
        <div class="ad-label">${esc(labels.craving)}</div><div class="ad-bar"><div class="ad-fill ${cls(s.craving)}" style="width:${Math.round(s.craving)}%"></div></div>
      </div></div>`;
    }).join('');
  }

  window.addEventListener('message', ({ data }) => {
    const msg = data || {};
    if (msg.action === 'addiction:open') {
      labels = msg.labels; stageLabel = msg.stageLabel || null;
      document.getElementById('ad-title').textContent = labels.title;
      document.getElementById('ad-subtitle').textContent = labels.subtitle;
      render(msg.data); root.classList.remove('hidden');
    } else if (msg.action === 'addiction:update') render(msg.data);
    else if (msg.action === 'addiction:close') root.classList.add('hidden');
  });

  document.getElementById('ad-close').addEventListener('click', () => post('addictionClose'));
  document.addEventListener('keyup', (e) => { if ((e.key === 'Escape' || e.key === 'Backspace') && !root.classList.contains('hidden')) post('addictionClose'); });
})();

// Rehab countdown HUD
(() => {
  const hud = document.getElementById('rehab-hud');
  const time = document.getElementById('rh-time'), fill = document.getElementById('rh-fill');
  let end = 0, total = 1, timer = null;
  const fmt = (s) => { s = Math.max(0, Math.ceil(s)); const m = Math.floor(s / 60); return `${String(m).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`; };
  const tick = () => {
    const left = Math.max(0, (end - Date.now()) / 1000);
    time.textContent = fmt(left);
    fill.style.width = (100 - (left / total) * 100) + '%'; // fills up as the sentence is served
  };
  window.addEventListener('message', ({ data }) => {
    const m = data || {};
    if (m.action === 'rehab:hud') {
      // keep the stint's full length across syncs: a sync without a total must not restart the bar
      const fresh = hud.classList.contains('hidden');
      total = Math.max(1, m.total || 0, m.left, fresh ? 0 : total);
      end = Date.now() + m.left * 1000;
      document.getElementById('rh-title').textContent = m.title || '';
      document.getElementById('rh-sub').textContent = m.sub || '';
      hud.classList.remove('hidden'); tick();
      if (!timer) timer = setInterval(tick, 1000);
    } else if (m.action === 'rehab:hide') {
      hud.classList.add('hidden'); clearInterval(timer); timer = null;
    }
  });
})();
