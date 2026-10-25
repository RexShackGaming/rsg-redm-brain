// Brick export panel. Shares the rsg-drugs NUI page.
(() => {
  const RES_E = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-drugs';
  const root = document.getElementById('export');
  const $e = (s) => root.querySelector(s);
  let L = {}, d = null;
  const t = (k, ...a) => { let i = 0; return String(L[k] ?? k).replace(/%%|%s/g, (m) => m === '%%' ? '%' : String(a[i++] ?? '')); };
  const money = (n) => '$' + Number(n).toLocaleString('en-US');
  const post = (name, body = {}) => fetch(`https://${RES_E}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }).then((r) => r.json()).catch(() => null);

  function chart(points) {
    const pts = [...points, d.price];
    const lo = d.minPrice * 0.9, hi = d.maxPrice * 1.25;
    const xy = pts.map((p, i) => `${(i / Math.max(1, pts.length - 1)) * 100},${100 - ((p - lo) / (hi - lo)) * 100}`).join(' ');
    return `<svg viewBox="0 0 100 100" preserveAspectRatio="none"><polyline points="${xy}" fill="none" stroke="#fff" stroke-width="1.5" vector-effect="non-scaling-stroke"/></svg>`;
  }

  function demandLabel() {
    const f = d.stock / d.saturation;
    if (f < 0.15) return ['ui_ex_hungry', 'stat-good'];
    if (f < 0.5) return ['ui_ex_steady', 'stat-good'];
    if (f < 0.85) return ['ui_ex_saturated', 'stat-warn'];
    return ['ui_ex_flooded', 'stat-bad'];
  }

  function render() {
    const prev = d.history.length ? d.history[d.history.length - 1] : d.price;
    const diff = d.price - prev;
    const trend = diff > 0 ? ['up', '▲'] : diff < 0 ? ['down', '▼'] : ['flat', '■'];
    const [dl, dc] = demandLabel();
    const fill = Math.min(100, (d.stock / d.saturation) * 100);
    const max = Math.min(d.maxPerSale, d.carrying);
    const qtyEl = $e('[data-qty]');
    const qty = Math.max(1, Math.min(max || 1, Number(qtyEl ? qtyEl.value : 1) || 1));
    $e('#ex-body').innerHTML = `
      <div class="ex-price"><div class="k">${t('ui_ex_price')}</div><div class="v">${money(d.price)}<span class="ex-trend ${trend[0]}">${trend[1]}</span></div></div>
      <div class="ex-chart">${chart(d.history)}</div>
      <div class="ex-meta"><span>${t('ui_ex_trend', d.history.length)}</span><span>${money(d.minPrice)} – ${money(d.maxPrice)}</span></div>
      <div class="label">${t('ui_ex_demand')} · ${t(dl)}</div>
      <div class="track"><div class="fill ${dc}" style="width:${fill}%"></div></div>
      <div class="ex-meta" style="margin-top:4px"><span>${t('ui_ex_stock', d.stock)}</span><span>${t('ui_carry', d.carrying)}</span></div>
      <div class="divider"><span>✦</span></div>
      <div class="ex-sell">
        <input class="qty" type="number" min="1" max="${max}" value="${qty}" data-qty ${max < 1 ? 'disabled' : ''}>
        <div class="ex-total">${max >= 1 ? t('ui_ex_total', `<b>${money(d.quotes[qty - 1])}</b>`) : t('ui_ex_none')}</div>
        <button class="btn muted" id="ex-max" ${max < 1 ? 'disabled' : ''}>${t('ui_max')}</button>
        <button class="btn" id="ex-go" ${max < 1 ? 'disabled' : ''}>${t('ui_ex_sell')}</button>
      </div>
      <div class="ex-note">${t('ui_ex_note', d.maxPerSale)}</div>`;
  }

  // only refresh the total while typing so the input keeps focus
  root.addEventListener('input', (e) => {
    if (!e.target.matches('[data-qty]')) return;
    const max = Math.min(d.maxPerSale, d.carrying);
    const q = Math.max(1, Math.min(max, Math.floor(Number(e.target.value) || 1)));
    $e('.ex-total').innerHTML = t('ui_ex_total', `<b>${money(d.quotes[q - 1])}</b>`);
  });
  root.addEventListener('click', async (e) => {
    if (e.target.id === 'ex-max') { $e('[data-qty]').value = Math.min(d.maxPerSale, d.carrying); render(); }
    if (e.target.id === 'ex-go') {
      e.target.disabled = true;
      const max = Math.min(d.maxPerSale, d.carrying);
      const amount = Math.max(1, Math.min(max, Math.floor(Number($e('[data-qty]').value) || 1)));
      const res = await post('exportSell', { amount });
      if (res) d = res;
      render();
    }
  });
  $e('#ex-close').addEventListener('click', () => post('exportClose'));
  document.addEventListener('keyup', (e) => { if (e.key === 'Escape' && !root.classList.contains('hidden')) post('exportClose'); });

  window.addEventListener('message', ({ data }) => {
    const m = data || {};
    if (m.action === 'export:open') {
      L = m.locale || L; d = m.data;
      $e('#ex-title').textContent = t('ui_ex_title'); $e('#ex-subtitle').textContent = t('ui_ex_subtitle');
      render(); root.classList.remove('hidden');
    } else if (m.action === 'export:close') root.classList.add('hidden');
  });
})();
