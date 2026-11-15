// rsg-stables: admin panel NUI. The server re-validates everything; this file only builds the forms and relays requests.
(function () {
  const res = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'rsg-stables';
  const post = (name, data) => fetch(`https://${res}/${name}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data || {}),
  }).then((r) => r.json()).catch(() => ({ ok: false, data: null }));

  const $ = (id) => document.getElementById(id);
  const modal = $('adminModal'), body = $('admBody'), msg = $('admMsg'), backBtn = $('admBackBtn');
  let S = {}, opts = null, open = false, view = null, player = null, horse = null, lastQuery = '';

  const el = (tag, cls, text) => { const e = document.createElement(tag); if (cls) e.className = cls; if (text !== undefined) e.textContent = text; return e; };
  const say = (text, kind) => { msg.textContent = text || ''; msg.className = 'adm-msg' + (kind ? ' ' + kind : ''); };

  // ---- pure HTML dropdown ----
  function closeDds() { document.querySelectorAll('.dd.open').forEach((d) => d.classList.remove('open')); }
  document.addEventListener('mousedown', (e) => { if (!e.target.closest('.dd')) closeDds(); });
  function dropdown(options, value) {
    const dd = el('div', 'dd');
    const val = el('div', 'dd-value'), label = el('span'), arrow = el('span', 'dd-arrow', '▾');
    val.append(label, arrow);
    const menu = el('div', 'dd-menu');
    dd.append(val, menu);
    dd.dataset.value = value == null ? '' : String(value);
    const refresh = () => {
      const cur = options.find((o) => String(o.value) === dd.dataset.value);
      label.textContent = cur ? cur.label : '';
      menu.querySelectorAll('.dd-opt').forEach((n) => n.classList.toggle('sel', n.dataset.value === dd.dataset.value));
    };
    options.forEach((o) => {
      const n = el('div', 'dd-opt', o.label); n.dataset.value = String(o.value);
      n.addEventListener('mousedown', (e) => { e.preventDefault(); dd.dataset.value = n.dataset.value; dd.classList.remove('open'); refresh(); });
      menu.appendChild(n);
    });
    val.addEventListener('click', () => { const was = dd.classList.contains('open'); closeDds(); if (!was) dd.classList.add('open'); });
    refresh();
    return dd;
  }

  function field(labelText, control) {
    const f = el('div', 'adm-field'); f.append(el('label', null, labelText), control); return f;
  }
  function input(value, type, attrs) {
    const i = el('input', 'adm-input'); i.type = type || 'text'; i.value = value == null ? '' : value;
    if (attrs) Object.keys(attrs).forEach((k) => i.setAttribute(k, attrs[k]));
    return i;
  }
  function btn(text, cls, fn) { const b = el('button', 'wood-btn' + (cls ? ' ' + cls : ''), text); b.addEventListener('click', fn); return b; }
  function section(text) { return el('div', 'adm-section', text); }

  function setView(v, sub, showBack) {
    view = v; closeDds(); say('');
    $('admSub').textContent = sub || S.subtitle || '';
    backBtn.classList.toggle('hidden', !showBack);
    body.innerHTML = '';
    body.scrollTop = 0;
  }

  // ---- players ----
  async function searchPlayers(q) {
    lastQuery = q;
    const r = await post('adminSearch', { a: q });
    if (!r.ok) { say(r.data || S.error, 'err'); return; }
    renderPlayers(r.data || []);
  }
  function showPlayers() {
    setView('players', S.subtitle, false);
    const bar = el('div', 'adm-bar');
    const q = input(lastQuery, 'text', { placeholder: S.search_ph, maxlength: 40 });
    const go = btn(S.search, null, () => searchPlayers(q.value));
    q.addEventListener('keydown', (e) => { e.stopPropagation(); if (e.key === 'Enter') searchPlayers(q.value); });
    bar.append(q, go);
    const list = el('div'); list.id = 'admPlayers';
    body.append(bar, list);
    searchPlayers(lastQuery);
  }
  function renderPlayers(rows) {
    const list = $('admPlayers'); if (!list) return;
    list.innerHTML = '';
    if (!rows.length) { list.appendChild(el('div', 'adm-empty', S.no_players)); return; }
    rows.forEach((p) => {
      const r = el('div', 'adm-row'), main = el('div', 'adm-main');
      main.append(el('div', 'adm-name', p.name), el('div', 'adm-desc', p.citizenid + ' • ' + S.horses_n.replace('%d', p.horses)));
      r.append(main, el('span', 'adm-pill ' + (p.online ? 'good' : ''), p.online ? S.online : S.offline));
      r.addEventListener('click', () => openPlayer(p.citizenid));
      list.appendChild(r);
    });
  }

  // ---- a player's horses ----
  async function openPlayer(cid) {
    const r = await post('adminHorses', { a: cid });
    if (!r.ok) { say(r.data || S.error, 'err'); return; }
    player = r.data.player;
    showHorses(r.data.horses);
  }
  async function reloadPlayer() {
    const r = await post('adminHorses', { a: player.citizenid });
    if (r.ok) { player = r.data.player; return r.data.horses; }
    return [];
  }
  function stageLabel(st) { return S['stage_' + st] || st; }
  function showHorses(horses) {
    setView('horses', player.name + ' • ' + player.citizenid, true);
    body.append(btn(S.give, null, () => showGive()));
    body.lastChild.style.marginBottom = '12px';
    if (!horses.length) body.appendChild(el('div', 'adm-empty', S.no_horses));
    horses.forEach((h) => {
      const r = el('div', 'adm-row'), main = el('div', 'adm-main');
      const sex = h.gender === 'female' ? '♀' : '♂';
      main.append(el('div', 'adm-name', sex + ' ' + h.name),
        el('div', 'adm-desc', `${h.breed} • ${h.stable} • ${h.ageDays} ${S.days} • ${stageLabel(h.stage)}`));
      const state = !h.alive ? ['bad', S.status_dead] : h.active ? ['warn', S.status_out] : ['good', S.status_stored];
      r.append(main, el('span', 'adm-pill ' + state[0], state[1]));
      r.addEventListener('click', () => showHorse(h));
      body.appendChild(r);
    });
    backBtn.textContent = S.back; backBtn.onclick = showPlayers;
  }

  // ---- one horse ----
  function showHorse(h) {
    horse = h;
    setView('horse', `${h.name} • #${h.id}`, true);
    backBtn.textContent = S.back;
    backBtn.onclick = async () => showHorses(await reloadPlayer());
    if (h.active) say(S.busy_out, 'err');

    body.append(section(S.edit_title));
    const g = el('div', 'adm-grid');
    const name = input(h.name, 'text', { maxlength: 40 });
    const gender = dropdown([{ value: 'male', label: S.male }, { value: 'female', label: S.female }], h.gender);
    const stable = dropdown(opts.stables, h.stable);
    const age = input(h.ageDays, 'number', { min: 0, max: 3650 });
    const insured = dropdown([{ value: '1', label: S.yes }, { value: '0', label: S.no }], h.insured ? '1' : '0');
    const born = dropdown([{ value: '1', label: S.yes }, { value: '0', label: S.no }], h.born ? '1' : '0');
    g.append(field(S.f_name, name), field(S.f_gender, gender), field(S.f_stable, stable), field(S.f_age, age), field(S.f_insured, insured), field(S.f_foal, born));
    const nums = {};
    [['health', 0, 100], ['stamina', 0, 100], ['hunger', 0, 100], ['thirst', 0, 100], ['bonding', 0, 100], ['handling', 0, 100],
      ['speed', 1, opts.statMax], ['accel', 1, opts.statMax], ['maxhealth', 1, opts.statMax]].forEach(([k, lo, hi]) => {
      nums[k] = input(h[k], 'number', { min: lo, max: hi }); g.appendChild(field(S['f_' + k], nums[k]));
    });
    [name, age, ...Object.values(nums)].forEach((i) => i.addEventListener('keydown', (e) => e.stopPropagation()));
    body.append(g);
    const saveRow = el('div', 'adm-btns'); body.append(saveRow);
    const save = btn(S.save, null, async () => {
      const ch = { name: name.value, gender: gender.dataset.value, stable: stable.dataset.value, ageDays: Number(age.value),
        insured: insured.dataset.value === '1', born: born.dataset.value === '1' };
      Object.keys(nums).forEach((k) => { ch[k] = Number(nums[k].value); });
      const r = await post('adminUpdate', { a: h.id, b: ch });
      say(r.data || (r.ok ? '' : S.error), r.ok ? 'ok' : 'err');
      if (r.ok) { const hs = await reloadPlayer(); const nh = hs.find((x) => x.id === h.id); if (nh) horse = nh; }
    });
    save.disabled = !!h.active;
    saveRow.append(save);

    body.append(section(S.actions));
    const acts = el('div', 'adm-btns');
    ['forceStore', 'revive', 'resetShoes', 'resetCoat', 'resetTack', 'resetTraining', 'clearCooldown', 'openSaddlebags'].forEach((a) => {
      acts.appendChild(btn(S['a_' + a], null, async () => {
        const r = await post('adminAction', { a: h.id, b: a });
        say(r.data || (r.ok ? '' : S.error), r.ok ? 'ok' : 'err');
        if (r.ok && a !== 'openSaddlebags') { const hs = await reloadPlayer(); const nh = hs.find((x) => x.id === h.id); if (nh) showHorse(nh); say(r.data, 'ok'); }
        if (r.ok && a === 'openSaddlebags') post('adminClose');
      }));
    });
    body.append(acts);

    body.append(section(S.transfer_title));
    const tb = el('div', 'adm-bar'), target = input('', 'text', { placeholder: S.transfer_ph, maxlength: 50 });
    target.addEventListener('keydown', (e) => e.stopPropagation());
    tb.append(target, btn(S.transfer, null, async () => {
      const r = await post('adminTransfer', { a: h.id, b: target.value });
      say(r.data || (r.ok ? '' : S.error), r.ok ? 'ok' : 'err');
      if (r.ok) showHorses(await reloadPlayer());
    }));
    body.append(tb);

    body.append(section(S.danger));
    const del = btn(S.delete, 'adm-danger', async () => {
      if (!del.dataset.sure) { del.dataset.sure = '1'; del.textContent = S.confirm_delete; return; }
      const r = await post('adminAction', { a: h.id, b: 'delete' });
      if (r.ok) { showHorses(await reloadPlayer()); say(r.data, 'ok'); } else say(r.data || S.error, 'err');
    });
    const delRow = el('div', 'adm-btns'); delRow.append(del); body.append(delRow);
  }

  // ---- give a horse ----
  function showGive() {
    setView('give', S.give_title + ' • ' + player.name, true);
    backBtn.textContent = S.back;
    backBtn.onclick = async () => showHorses(await reloadPlayer());
    const g = el('div', 'adm-grid');
    const breed = dropdown(opts.breeds, opts.breeds[0] && opts.breeds[0].value);
    const name = input('', 'text', { maxlength: 40 });
    const gender = dropdown([{ value: 'male', label: S.male }, { value: 'female', label: S.female }], 'male');
    const stable = dropdown(opts.stables, opts.stables[0] && opts.stables[0].value);
    const age = input(0, 'number', { min: 0, max: 3650 });
    const foal = dropdown([{ value: '0', label: S.no }, { value: '1', label: S.yes }], '0');
    name.addEventListener('keydown', (e) => e.stopPropagation()); age.addEventListener('keydown', (e) => e.stopPropagation());
    g.append(field(S.f_breed, breed), field(S.f_name, name), field(S.f_gender, gender), field(S.f_stable, stable), field(S.f_age, age), field(S.f_foal, foal));
    const giveRow = el('div', 'adm-btns'); body.append(g, giveRow);
    giveRow.append(btn(S.give, null, async () => {
      const r = await post('adminGive', { a: player.citizenid, b: breed.dataset.value, c: name.value, d: gender.dataset.value,
        e: stable.dataset.value, f: Number(age.value), g: foal.dataset.value === '1' });
      say(r.data || (r.ok ? '' : S.error), r.ok ? 'ok' : 'err');
      if (r.ok) { const m = r.data; showHorses(await reloadPlayer()); say(m, 'ok'); }
    }));
  }

  function close() { if (!open) return; open = false; modal.classList.add('hidden'); post('adminClose'); }
  $('admCloseBtn').addEventListener('click', close);
  document.addEventListener('keydown', (e) => { if (open && e.key === 'Escape') close(); });

  window.addEventListener('message', async (event) => {
    const d = event.data;
    if (!d) return;
    if (d.action === 'adminOpen') {
      S = d.strings || {};
      $('admTitle').textContent = S.title || '';
      $('admCloseBtn').textContent = S.close || 'Close';
      open = true; modal.classList.remove('hidden');
      lastQuery = ''; say(S.loading);
      const r = await post('adminOptions');
      if (!r.ok) { say(r.data || S.error, 'err'); return; }
      opts = r.data; showPlayers();
    } else if (d.action === 'adminClose') {
      open = false; modal.classList.add('hidden');
    }
  });
})();
