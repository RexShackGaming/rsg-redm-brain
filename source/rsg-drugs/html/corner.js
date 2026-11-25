// Corner selling haggle panel. Shares the rsg-drugs NUI page. The server runs the haggle; this only shows it
// and sends the price the player typed (the server clamps and validates every value).
(() => {
  const RES_C = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-drugs';
  const IMG = 'nui://rsg-inventory/html/images/';
  const root = document.getElementById('corner');
  const $c = (s) => root.querySelector(s);
  let L = {}, d = null, price = 0, busy = false, final = null;
  const t = (k, ...a) => { let i = 0; return String(L[k] ?? k).replace(/%%|%s/g, (m) => m === '%%' ? '%' : String(a[i++] ?? '')); };
  const money = (n) => '$' + Number(n || 0).toFixed(2);
  const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const post = (name, body = {}) => fetch(`https://${RES_C}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }).then((r) => r.json()).catch(() => null);
  const round2 = (n) => Math.round(n * 100) / 100;
  const clampPrice = (n) => { n = round2(Number(n) || 0); return Math.max(d.minPrice || 0.01, d.maxPrice ? Math.min(n, d.maxPrice) : n); };

  const patienceClass = () => { const r = d.patience / d.maxPatience; return r > 0.6 ? 'stat-good' : r > 0.3 ? 'stat-warn' : 'stat-bad'; };

  function icon() {
    const letter = esc((d.label || '?').charAt(0).toUpperCase());
    return `<div class="badge-icon img"><img src="${IMG}${esc(d.item)}.png" alt="" onerror="this.parentElement.classList.remove('img');this.parentElement.textContent='${letter}'"></div>`;
  }

  function finalBanner() {
    if (!final) return '';
    if (final.done === 'sold') return `<div class="cn-final ok">${t('ui_cn_done')}<small>${t('ui_cn_done_sub', final.qty, d.label, money(final.price), money(final.total))}</small></div>`;
    if (final.done === 'law') return `<div class="cn-final bad">${t('ui_cn_reported')}</div>`;
    if (final.done === 'walk') return `<div class="cn-final bad">${t('ui_cn_walked')}</div>`;
    return `<div class="cn-final bad">${t('ui_cn_lost')}</div>`;
  }

  function render() {
    const line = (final && final.line) || d.line;
    const pct = Math.max(0, Math.min(100, (d.patience / d.maxPatience) * 100));
    const locked = busy || !!final;
    const hist = (d.history || []).slice().reverse().map((h) => `<div><span>${t('ui_cn_you')} <b>${money(h.ask)}</b></span><span>${t('ui_cn_they')} <b>${money(h.offer)}</b></span></div>`).join('');
    $c('#cn-body').innerHTML = `
      <div class="cn-say"><div class="k">${t('ui_cn_buyer')}</div><div class="q">${line ? '“' + esc(t(line, money(d.offer))) + '”' : ''}</div></div>
      <div class="row cn-item">${icon()}<div class="grow"><div class="name">${d.qty}× ${esc(d.label)}</div><div class="desc">${d.street != null ? t('ui_cn_street', money(d.street)) : ''}</div>${d.avg != null ? `<div class="desc">${t(d.avgTown ? 'ui_cn_market_town' : 'ui_cn_market', money(d.avg), d.avgN)}</div>` : ''}${d.demand ? `<div class="desc">${t('ui_cn_demand', d.demand)}</div>` : ''}${d.rankLabel ? `<div class="desc">${t('ui_cn_rank', t(d.rankLabel), d.rankBonus || 0)}</div>` : ''}</div>${d.regular ? `<span class="pill">${t('ui_cn_regular', esc(d.regular.name), d.regular.lvl)}</span> ` : ''}${d.buyer ? `<span class="pill">${t('ui_cn_buyer_' + d.buyer)}</span> ` : ''}${d.potency != null ? `<span class="pill">${t('ui_cn_potency', d.potency)}</span>` : ''}</div>
      ${d.offer != null && !final ? `<div class="cn-offer"><div class="k">${t('ui_cn_offer')}</div><div class="v">${money(d.offer)} <small>${t('ui_cn_each')}</small></div><div class="sub">${money(d.offer * d.qty)} ${t('ui_cn_total')}</div></div>` : ''}
      <div class="label">${t('ui_cn_patience')}</div>
      <div class="track"><div class="fill ${patienceClass()}" style="width:${pct}%"></div></div>
      <div class="divider"><span>✦</span></div>
      <div class="label" style="margin-top:0;text-align:center">${t('ui_cn_your_price')}</div>
      <div class="cn-price">
        <button class="circle-btn" data-step="-1" ${locked ? 'disabled' : ''}>−</button>
        <input class="qty cn-input" type="text" inputmode="decimal" value="${price.toFixed(2)}" ${locked ? 'disabled' : ''}>
        <button class="circle-btn" data-step="1" ${locked ? 'disabled' : ''}>+</button>
        <span class="cn-each">${t('ui_cn_each')}</span>
      </div>
      <div class="cn-total">${t('ui_cn_total')} <b id="cn-sum">${money(price * d.qty)}</b></div>
      ${finalBanner()}
      <div class="cn-actions">
        <button class="btn" id="cn-offer" ${locked ? 'disabled' : ''}>${t('ui_cn_make_offer')}</button>
        ${d.offer != null ? `<button class="btn" id="cn-accept" ${locked ? 'disabled' : ''}>${t('ui_cn_accept', money(d.offer))}</button>` : ''}
        <button class="btn muted" id="cn-walk" ${final ? 'disabled' : ''}>${t('ui_cn_walk')}</button>
      </div>
      ${hist ? `<div class="label">${t('ui_cn_history')}</div><div class="cn-hist">${hist}</div>` : ''}`;
  }

  function apply(res) {
    busy = false;
    if (!res) return render();
    if (res.done) { final = res; return render(); }
    d = { ...d, ...res };
    render();
  }

  async function submit() {
    if (busy || final || !d) return;
    busy = true; render();
    apply(await post('cornerOffer', { price }));
  }

  async function accept() {
    if (busy || final || !d || d.offer == null) return;
    busy = true; render();
    apply(await post('cornerAccept'));
  }

  // typing only refreshes the total so the input keeps focus
  root.addEventListener('input', (e) => {
    if (!e.target.matches('.cn-input')) return;
    price = Number(String(e.target.value).replace(',', '.')) || 0;
    const s = $c('#cn-sum'); if (s) s.textContent = money(price * d.qty);
  });
  root.addEventListener('change', (e) => {
    if (!e.target.matches('.cn-input')) return;
    price = clampPrice(price); render();
  });
  root.addEventListener('keydown', (e) => { if (e.key === 'Enter' && e.target.matches('.cn-input')) { price = clampPrice(price); submit(); } });
  root.addEventListener('click', (e) => {
    const b = e.target.closest('button'); if (!b || !d) return;
    if (b.dataset.step) { price = clampPrice(price + Number(b.dataset.step) * (d.step || 0.05)); render(); }
    else if (b.id === 'cn-offer') { price = clampPrice(price); submit(); }
    else if (b.id === 'cn-accept') accept();
    else if (b.id === 'cn-walk' || b.id === 'cn-close') post('cornerClose');
  });
  document.addEventListener('keyup', (e) => { if (e.key === 'Escape' && !root.classList.contains('hidden') && !final) post('cornerClose'); });

  window.addEventListener('message', ({ data }) => {
    const m = data || {};
    if (m.action === 'corner:open') {
      L = m.locale || L; d = m.data; busy = false; final = null;
      price = clampPrice(d.street != null ? Math.round(d.street * 1.15 / (d.step || 0.05)) * (d.step || 0.05) : 5);
      $c('#cn-title').textContent = t('ui_cn_title'); $c('#cn-subtitle').textContent = t('ui_cn_subtitle');
      render(); root.classList.remove('hidden');
    } else if (m.action === 'corner:close') { root.classList.add('hidden'); d = null; final = null; busy = false; }
  });
})();
