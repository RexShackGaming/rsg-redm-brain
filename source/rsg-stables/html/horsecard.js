// rsg-stables: live horse information card
(function () {
  const res = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'rsg-stables';
  const post = (n, d) => fetch(`https://${res}/${n}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(d || {}) }).catch(() => {});
  const $ = (id) => document.getElementById(id);
  const root = $('horseCard'), body = $('hcBody'), actions = $('hcActions');
  let S = {}, data = null, tab = 'condition';
  const t = (k, ...a) => { let s = S[k] !== undefined ? String(S[k]) : k; a.forEach((v) => { s = s.replace('%s', v); }); return s; };
  const el = (tag, cls, text) => { const e = document.createElement(tag); if (cls) e.className = cls; if (text !== undefined) e.textContent = text; return e; };
  const barClass = (v) => (v <= 15 ? 'stat-bad' : v <= 35 ? 'stat-warn' : 'stat-good');

  function statRow(label, valueText, pct, cls) {
    const row = el('div', 'hc-row');
    const top = el('div', 'stat-row-top');
    top.appendChild(el('span', 'stat-label', label));
    top.appendChild(el('span', 'stat-value', valueText));
    row.appendChild(top);
    const track = el('div', 'stat-bar-track');
    const fill = el('div', 'stat-bar-fill ' + cls);
    fill.style.width = Math.max(0, Math.min(100, pct)) + '%';
    track.appendChild(fill);
    row.appendChild(track);
    return row;
  }

  function renderCondition() {
    data.condition.forEach((c) => {
      const row = statRow(c.label, `${Math.round(c.value)}%`, c.value, barClass(c.value));
      if (c.hint) row.appendChild(el('div', 'hc-hint ' + c.hint.level, c.hint.text));
      body.appendChild(row);
    });
  }

  function renderPerformance() {
    data.perf.forEach((p) => {
      const base = p.base || 0;
      const total = base + p.tack + p.trained;
      const row = el('div', 'hc-row');
      const top = el('div', 'stat-row-top');
      top.appendChild(el('span', 'stat-label', p.label));
      const parts = [];
      if (p.base !== undefined && p.base !== null) parts.push(`${base}`);
      if (p.tack) parts.push(`+${p.tack}`);
      if (p.trained) parts.push(`+${p.trained}`);
      top.appendChild(el('span', 'stat-value', parts.join(' ')));
      row.appendChild(top);
      const segs = el('div', 'hc-segs');
      const n = Math.max(p.max || 10, total);
      for (let i = 0; i < n; i++) {
        let cls = '';
        if (i < base) cls = 'base'; else if (i < base + p.tack) cls = 'tack'; else if (i < total) cls = 'trained';
        segs.appendChild(el('div', 'hc-seg ' + cls));
      }
      row.appendChild(segs);
      body.appendChild(row);
    });
    const legend = el('div', 'hc-legend');
    [['base', '#c8c8c8'], ['tack', '#d9a441'], ['trained', '#6fbf73']].forEach(([k, col]) => {
      const span = el('span');
      const sw = el('i'); sw.style.background = col;
      span.appendChild(sw); span.appendChild(document.createTextNode(t('card_' + k)));
      legend.appendChild(span);
    });
    body.appendChild(legend);
  }

  function renderTraining() {
    if (!data.training || !data.training.length) { body.appendChild(el('div', 'hc-note', '—')); return; }
    data.training.forEach((s) => {
      const maxed = !s.nextXp;
      const pct = maxed ? 100 : ((s.xp - s.prevXp) / Math.max(1, s.nextXp - s.prevXp)) * 100;
      const row = statRow(s.label, t('training_level', s.level, s.max), pct, maxed ? 'stat-good' : 'stat-warn');
      row.appendChild(el('div', 'hc-xp', maxed ? t('training_maxed') : `${s.xp} / ${s.nextXp} XP`));
      body.appendChild(row);
    });
  }

  function render() {
    if (!data) return;
    $('hcName').textContent = data.name;
    $('hcSub').textContent = [data.breed, data.gender, `${data.stage} · ${t('card_days', data.ageDays)}`].filter(Boolean).join(' · ');

    const badges = $('hcBadges'); badges.innerHTML = '';
    (data.badges || []).forEach((b) => badges.appendChild(el('span', 'hc-badge ' + (b.level || ''), b.text)));

    $('hcBondLabel').textContent = t('card_bond', data.bond.pct);
    const pips = $('hcBondPips'); pips.innerHTML = '';
    for (let i = 1; i <= data.bond.max; i++) pips.appendChild(el('div', 'hc-pip' + (i <= data.bond.rank ? ' on' : '')));

    document.querySelectorAll('.hc-tab').forEach((b) => {
      b.textContent = t('card_' + b.dataset.tab);
      b.classList.toggle('active', b.dataset.tab === tab);
      b.style.display = (b.dataset.tab === 'training' && !data.training) ? 'none' : '';
    });

    const scroll = body.scrollTop;
    body.innerHTML = '';
    if (tab === 'condition') renderCondition();
    else if (tab === 'performance') renderPerformance();
    else renderTraining();
    body.scrollTop = scroll;

    actions.innerHTML = '';
    [['feed', 'card_feed'], ['water', 'card_water'], ['brush', 'card_brush'], ['train', 'card_train']].forEach(([a, key]) => {
      if (a === 'train' && !data.actions.train) return;
      const btn = el('button', 'wood-btn', t(key));
      btn.disabled = !data.actions[a] || (data.mounted && a !== 'train');
      btn.addEventListener('click', () => post('horseCardAction', { action: a }));
      actions.appendChild(btn);
    });
    let note = root.querySelector('.hc-note.mounted');
    if (data.mounted && !note) { note = el('div', 'hc-note mounted', t('card_dismount_hint')); actions.after(note); }
    if (!data.mounted && note) note.remove();
  }

  function close() { root.classList.add('hidden'); post('horseCardClose'); }

  document.querySelectorAll('.hc-tab').forEach((b) => b.addEventListener('click', () => { tab = b.dataset.tab; render(); }));
  $('hcClose').addEventListener('click', close);
  document.addEventListener('keydown', (e) => {
    if (root.classList.contains('hidden')) return;
    if (e.key === 'Escape' || e.key === 'Backspace') close();
    if (e.key === '1') { tab = 'condition'; render(); }
    if (e.key === '2') { tab = 'performance'; render(); }
    if (e.key === '3' && data && data.training) { tab = 'training'; render(); }
  });

  window.addEventListener('message', (ev) => {
    const d = ev.data;
    if (!d) return;
    if (d.action === 'horseCardOpen') {
      S = Object.assign({}, d.strings || {}); data = d.data; tab = 'condition';
      $('hcClose').title = t('card_close');
      root.classList.remove('hidden'); render();
    } else if (d.action === 'horseCardUpdate') {
      if (!root.classList.contains('hidden')) { data = d.data; render(); }
    } else if (d.action === 'horseCardClose') {
      root.classList.add('hidden');
    }
  });
})();
