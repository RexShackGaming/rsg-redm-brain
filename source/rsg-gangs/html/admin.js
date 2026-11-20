(function () {
  const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-gangs';
  const $ = (id) => document.getElementById(id);

  const app = $('app');
  const view = $('adminView');
  if (!app || !view) return;

  let L = {};
  let isOpen = false;
  let busy = false;
  let detailToken = 0;

  const S = {
    snap: null,        // { gangs, stats, territories, ranks, tiers, colors, limits }
    selected: null,    // selected gang id
    detail: null,      // full data of the selected gang
    logs: [],
    sub: 'details',
    tab: 'gangs',
    players: [],
    search: '',
    playerSearch: '',
  };

  // ---------- Helpers ----------
  function t(key, ...args) {
    const text = L[key] != null ? String(L[key]) : key;
    let i = 0;
    return text.replace(/%[sd]/g, () => (i < args.length ? args[i++] : ''));
  }
  const fmtMoney = (n) => '$' + (Number(n) || 0).toLocaleString('en-US');
  function esc(value) {
    const div = document.createElement('div');
    div.textContent = value == null ? '' : String(value);
    return div.innerHTML;
  }
  const safeColor = (c) => (/^#[0-9a-f]{6}$/i.test(c || '') ? c : '#e63946');

  function el(tag, cls, html) {
    const node = document.createElement(tag);
    if (cls) node.className = cls;
    if (html != null) node.innerHTML = html;
    return node;
  }

  function button(label, cls, onClick) {
    const b = el('button', 'btn ' + (cls || ''));
    b.textContent = label;
    b.addEventListener('click', onClick);
    return b;
  }

  function toast(message, type) {
    const node = el('div', 'toast ' + (type || ''));
    node.textContent = message;
    $('toasts').appendChild(node);
    setTimeout(() => node.remove(), 3500);
  }

  function post(endpoint, data) {
    return fetch(`https://${RESOURCE}/${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).catch(() => null);
  }

  async function call(action, payload) {
    try {
      const response = await fetch(`https://${RESOURCE}/adminCall`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ action, payload: payload || {} }),
      });
      return await response.json();
    } catch (e) {
      return null;
    }
  }

  // Runs a write action, shows the server's answer, then reloads what is on screen.
  async function act(action, payload) {
    if (busy) return null;
    busy = true;
    view.classList.add('busy');
    const res = await call(action, payload);
    busy = false;
    view.classList.remove('busy');
    if (!res) { toast(t('ui_adm_error'), 'error'); return null; }
    if (!res.ok) { toast(res.error || t('ui_adm_error'), 'error'); return res; }
    if (res.message) toast(res.message, 'success');
    if (res.removed && S.selected === res.removed) { S.selected = null; S.detail = null; }
    await refresh();
    return res;
  }

  // ---------- Pure HTML dropdown ----------
  let openDd = null; // { root, menu }
  function closeDd() {
    if (!openDd) return;
    openDd.root.classList.remove('open');
    openDd.menu.classList.add('hidden');
    openDd.root.appendChild(openDd.menu);
    openDd = null;
  }
  function showDd(root, menu) {
    closeDd();
    const rect = root.getBoundingClientRect();
    document.body.appendChild(menu);
    menu.classList.remove('hidden');
    menu.style.left = rect.left + 'px';
    menu.style.minWidth = rect.width + 'px';
    const height = Math.min(menu.scrollHeight, 220);
    const below = window.innerHeight - rect.bottom;
    menu.style.top = (below >= height + 8 || rect.top < height ? rect.bottom + 4 : rect.top - height - 4) + 'px';
    root.classList.add('open');
    openDd = { root, menu };
  }
  document.addEventListener('mousedown', (e) => {
    if (openDd && !e.target.closest('.dd') && !e.target.closest('.dd-menu')) closeDd();
  });
  document.addEventListener('scroll', (e) => {
    if (openDd && !(e.target.closest && e.target.closest('.dd-menu'))) closeDd();
  }, true);

  // options: [{ value, label }]. Returns the element; read the value from `.dataset.value`.
  function makeDd(options, value, onChange, settings) {
    settings = settings || {};
    const root = el('div', 'dd' + (settings.disabled ? ' disabled' : ''));
    root.dataset.value = value == null ? '' : String(value);
    const head = el('div', 'dd-value');
    const label = el('span', 'dd-label');
    head.append(label, el('span', 'dd-arrow', '&#9662;'));
    const menu = el('div', 'dd-menu hidden');
    root.append(head, menu);

    const setLabel = () => {
      const found = options.find((o) => String(o.value) === root.dataset.value);
      label.textContent = found ? found.label : (settings.placeholder || '');
      menu.querySelectorAll('.dd-opt').forEach((n) => n.classList.toggle('selected', n.dataset.value === root.dataset.value));
    };
    options.forEach((o) => {
      const item = el('div', 'dd-opt');
      item.textContent = o.label;
      item.dataset.value = String(o.value);
      item.addEventListener('mousedown', (e) => {
        e.preventDefault();
        e.stopPropagation();
        root.dataset.value = String(o.value);
        setLabel();
        closeDd();
        if (onChange) onChange(o.value);
      });
      menu.appendChild(item);
    });
    head.addEventListener('mousedown', (e) => {
      e.preventDefault();
      const wasOpen = root.classList.contains('open');
      closeDd();
      if (!wasOpen) { setLabel(); showDd(root, menu); }
    });
    setLabel();
    return root;
  }

  // ---------- Modal ----------
  let modalOk = null;
  function openModal(opts) {
    $('admModalTitle').textContent = opts.title || t('ui_adm_confirm_title');
    $('admModalText').textContent = opts.text || '';
    $('admModalText').classList.toggle('hidden', !opts.text);
    const body = $('admModalBody');
    body.innerHTML = '';
    if (opts.build) opts.build(body);
    $('admModalOk').textContent = opts.okLabel || t('ui_adm_confirm');
    $('admModalOk').classList.toggle('btn-danger', !!opts.danger);
    modalOk = opts.onOk || null;
    $('admModal').classList.remove('hidden');
  }
  function closeModal() {
    closeDd();
    $('admModal').classList.add('hidden');
    $('admModalBody').innerHTML = '';
    modalOk = null;
  }
  $('admModalCancel').addEventListener('click', closeModal);
  $('admModalOk').addEventListener('click', () => {
    const fn = modalOk;
    closeModal();
    if (fn) fn();
  });
  function confirmAction(text, onOk, danger) {
    openModal({ title: t('ui_adm_confirm_title'), text, onOk, danger });
  }

  // ---------- Loading ----------
  async function refresh() {
    const res = await call('snapshot');
    if (!res || !res.ok) { toast((res && res.error) || t('ui_adm_error'), 'error'); return; }
    S.snap = res;
    if (S.selected && !res.gangs.some((g) => g.name === S.selected)) { S.selected = null; S.detail = null; }
    renderStats();
    renderGangList();
    renderTerritories();
    renderCreateSwatches();
    if (S.selected) await loadDetail(); else renderDetail();
    if (S.tab === 'players') await loadPlayers();
  }

  async function loadDetail() {
    const token = ++detailToken;
    const res = await call('gang', { name: S.selected });
    if (token !== detailToken) return;
    if (!res || !res.ok) {
      toast((res && res.error) || t('ui_adm_error'), 'error');
      S.selected = null; S.detail = null;
      renderGangList();
      renderDetail();
      return;
    }
    S.detail = res.gang;
    S.logs = res.logs || [];
    renderDetail();
  }

  async function loadPlayers() {
    const res = await call('players');
    if (!res || !res.ok) return;
    S.players = res.players || [];
    renderPlayers();
  }

  function selectGang(name) {
    S.selected = name;
    S.detail = null;
    renderGangList();
    renderDetail();
    loadDetail();
  }

  // ---------- Rendering: header, lists ----------
  function renderStats() {
    const s = (S.snap && S.snap.stats) || {};
    $('admStatGangs').textContent = s.gangs || 0;
    $('admStatMembers').textContent = s.members || 0;
    $('admStatOnline').textContent = s.online || 0;
    $('admStatBank').textContent = fmtMoney(s.bank);
  }

  function gangTitle(g) {
    return (g.tag ? `[${esc(g.tag)}] ` : '') + esc(g.label);
  }

  function renderGangList() {
    const wrap = $('admGangList');
    wrap.innerHTML = '';
    if (!S.snap) return;
    const q = S.search.trim().toLowerCase();
    const gangs = S.snap.gangs.filter((g) => !q || g.label.toLowerCase().includes(q) || g.name.includes(q) || (g.tag || '').toLowerCase().includes(q));
    if (!gangs.length) { wrap.appendChild(el('div', 'empty', esc(t('ui_adm_no_gangs')))); return; }
    gangs.forEach((g) => {
      const r = el('div', 'list-row adm-gang' + (g.name === S.selected ? ' selected' : ''));
      r.innerHTML = `<span class="color-dot" style="background:${safeColor(g.color)}"></span>` +
        `<div class="row-info"><div class="row-title">${gangTitle(g)}</div>` +
        `<div class="row-sub">${esc(t('ui_adm_row_sub', g.members, g.online, fmtMoney(g.bank)))}</div></div>`;
      r.addEventListener('click', () => selectGang(g.name));
      wrap.appendChild(r);
    });
  }

  // ---------- Rendering: gang detail ----------
  function field(labelKey) {
    const box = el('div', 'block');
    box.appendChild(el('label', 'field-label', esc(t(labelKey))));
    return box;
  }

  function statCard(labelKey, value) {
    return el('div', 'stat-card', `<span class="stat-label">${esc(t(labelKey))}</span><span class="stat-value">${esc(value)}</span>`);
  }

  function amountOf(input) {
    const n = Number(input.value);
    if (!Number.isFinite(n) || n < 0 || Math.floor(n) !== n) { toast(t('ui_adm_bad_amount'), 'error'); return null; }
    return n;
  }

  function renderDetail() {
    const main = $('admGangMain');
    main.innerHTML = '';
    const g = S.detail;
    if (!g) {
      main.appendChild(el('div', 'empty', esc(t(S.selected ? 'ui_adm_loading' : 'ui_adm_pick_gang'))));
      return;
    }

    const head = el('div', 'adm-detail-head');
    head.innerHTML = `<span class="color-dot" style="background:${safeColor(g.color)}"></span>` +
      `<div><h2>${gangTitle(g)}</h2><div class="row-sub">${esc(g.name)}</div></div><span class="spacer"></span>`;
    main.appendChild(head);

    const tabs = el('div', 'adm-subtabs');
    ['details', 'members', 'bank', 'assets', 'log'].forEach((key) => {
      const b = el('button', 'adm-subtab' + (S.sub === key ? ' active' : ''));
      b.textContent = t('ui_adm_dt_' + key);
      b.addEventListener('click', () => { S.sub = key; renderDetail(); });
      tabs.appendChild(b);
    });
    main.appendChild(tabs);

    const body = el('div');
    ({ details: subDetails, members: subMembers, bank: subBank, assets: subAssets, log: subLog })[S.sub](body, g);
    main.appendChild(body);
  }

  function textSaveRow(value, maxLength, onSave) {
    const row = el('div', 'adm-inline');
    const input = el('input', 'input');
    input.value = value || '';
    input.maxLength = maxLength;
    row.append(input, button(t('ui_adm_save'), '', () => onSave(input.value.trim())));
    return row;
  }

  function subDetails(body, g) {
    const limits = S.snap.limits;
    const name = field('ui_adm_label');
    name.appendChild(textSaveRow(g.label, limits.maxName, (label) => { if (label) act('renameGang', { name: g.name, label }); }));
    body.appendChild(name);

    if (limits.tagsEnabled) {
      const tag = field('ui_adm_tag');
      tag.appendChild(textSaveRow(g.tag, limits.tagMax, (value) => act('setTag', { name: g.name, tag: value })));
      tag.appendChild(el('div', 'adm-note', esc(t('ui_adm_tag_note', limits.tagMin, limits.tagMax))));
      body.appendChild(tag);
    }

    const colour = field('ui_adm_color');
    const swatches = el('div', 'swatches');
    const hex = el('input', 'input adm-hex');
    hex.value = safeColor(g.color);
    hex.maxLength = 7;
    (S.snap.colors || []).forEach((c) => {
      const sw = el('div', 'swatch' + (c.toLowerCase() === (g.color || '').toLowerCase() ? ' selected' : ''));
      sw.style.background = c;
      sw.addEventListener('click', () => {
        hex.value = c;
        swatches.querySelectorAll('.swatch').forEach((n) => n.classList.remove('selected'));
        sw.classList.add('selected');
      });
      swatches.appendChild(sw);
    });
    colour.append(swatches, hex, el('div', 'adm-note', esc(t('ui_adm_color_note'))));
    colour.appendChild(button(t('ui_adm_save'), 'btn-small', () => act('setColor', { name: g.name, color: hex.value.trim() })));
    colour.lastChild.style.marginTop = '12px';
    body.appendChild(colour);

    const info = el('div', 'adm-grid');
    info.append(
      statCard('ui_adm_owner', g.ownerName || t('ui_adm_system')),
      statCard('ui_adm_stat_members', g.members + (S.snap.limits.maxMembers > 0 ? ' / ' + S.snap.limits.maxMembers : '')),
      statCard('ui_adm_stat_bank', fmtMoney(g.bank)),
    );
    body.appendChild(info);

    if ((S.snap.tiers || []).length) {
      const stash = field('ui_adm_stash');
      const row = el('div', 'adm-inline');
      const dd = makeDd(S.snap.tiers.map((x) => ({ value: x.id, label: x.label })), g.stashTier);
      row.append(dd, button(t('ui_adm_apply'), '', () => act('setStash', { name: g.name, tier: dd.dataset.value })));
      stash.appendChild(row);
      body.appendChild(stash);
    }

    if (limits.upkeepEnabled && g.upkeep) {
      const up = field('ui_adm_upkeep');
      const card = el('div', 'card');
      const due = g.upkeep.due ? new Date(g.upkeep.due * 1000).toLocaleString() : '-';
      card.appendChild(el('div', '', esc(t('ui_adm_upkeep_state', fmtMoney(g.upkeep.cost), due))));
      card.appendChild(el('div', 'row-sub' + (g.upkeep.missed > 0 ? ' warn' : ''), esc(t('ui_adm_upkeep_missed', g.upkeep.missed, g.upkeep.maxMissed))));
      const reset = button(t('ui_adm_reset_upkeep'), 'btn-muted btn-small', () => act('resetUpkeep', { name: g.name }));
      reset.style.alignSelf = 'flex-start';
      card.appendChild(reset);
      up.appendChild(card);
      body.appendChild(up);
    }

    const danger = el('div', 'danger-zone');
    danger.appendChild(button(t('ui_adm_disband'), 'btn-danger', () => {
      openModal({
        title: t('ui_adm_disband'),
        text: t('ui_adm_confirm_disband', g.label),
        danger: true,
        okLabel: t('ui_adm_disband'),
        onOk: () => act('deleteGang', { name: g.name }),
      });
    }));
    body.appendChild(danger);
  }

  function subMembers(body, g) {
    const ranks = S.snap.ranks || [];
    const joinRanks = ranks.filter((r) => !r.isLeader).map((r) => ({ value: r.name, label: r.label }));

    const add = field('ui_adm_add_member');
    const row = el('div', 'adm-inline');
    const id = el('input', 'input');
    id.inputMode = 'numeric';
    id.maxLength = 5;
    id.placeholder = t('ui_adm_player_id');
    const rankDd = makeDd(joinRanks, joinRanks.length ? joinRanks[0].value : '');
    row.append(id, rankDd, button(t('ui_adm_add'), '', () => {
      const serverId = Number(id.value);
      if (!Number.isInteger(serverId) || serverId < 1) { toast(t('ui_adm_bad_id'), 'error'); return; }
      act('addMember', { name: g.name, serverId, rank: rankDd.dataset.value });
      id.value = '';
    }));
    add.appendChild(row);
    body.appendChild(add);

    const list = el('div', 'list');
    if (!g.memberList.length) list.appendChild(el('div', 'empty', esc(t('ui_adm_no_members'))));
    g.memberList.forEach((m) => {
      const r = el('div', 'list-row');
      const sub = m.citizenid + (m.online ? ' · ' + t('ui_adm_online') + (m.source ? ' (' + m.source + ')' : '') : ' · ' + t('ui_adm_offline'));
      r.appendChild(el('div', 'row-info',
        `<div class="row-title"><span class="member-line"><span class="dot ${m.online ? 'online' : ''}"></span>${esc(m.name)}</span></div>` +
        `<div class="row-sub">${esc(sub)}</div>`));
      const actions = el('div', 'adm-member-actions');
      if (m.isLeader) {
        actions.appendChild(el('span', 'badge adm-badge-ok', esc(m.rankLabel)));
      } else {
        actions.appendChild(makeDd(joinRanks, m.rank, (rank) => act('setRank', { name: g.name, citizenid: m.citizenid, rank })));
        actions.appendChild(button(t('ui_adm_make_leader'), 'btn-small', () => confirmAction(
          t('ui_adm_confirm_leader', m.name, g.label),
          () => act('transferLeader', { name: g.name, citizenid: m.citizenid }))));
      }
      actions.appendChild(button(t('ui_adm_kick'), 'btn-small btn-danger', () => confirmAction(
        t('ui_adm_confirm_kick', m.name, g.label),
        () => act('removeMember', { name: g.name, citizenid: m.citizenid }), true)));
      r.appendChild(actions);
      list.appendChild(r);
    });
    body.appendChild(list);
  }

  function subBank(body, g) {
    body.appendChild(el('div', 'bank-hero',
      `<span class="stat-label">${esc(t('ui_adm_balance'))}</span><span class="adm-money">${esc(fmtMoney(g.bank))}</span>`));
    const row = el('div', 'adm-inline');
    const amount = el('input', 'input');
    amount.type = 'number';
    amount.min = '0';
    amount.placeholder = t('ui_adm_amount');
    const send = (mode) => () => {
      const value = amountOf(amount);
      if (value == null) return;
      act('bank', { name: g.name, mode, amount: value });
      amount.value = '';
    };
    row.append(amount, button(t('ui_adm_add'), '', send('add')), button(t('ui_adm_remove'), 'btn-muted', send('remove')), button(t('ui_adm_set'), 'btn-muted', send('set')));
    body.appendChild(row);
    body.appendChild(el('div', 'adm-note', esc(t('ui_adm_bank_note', fmtMoney(S.snap.limits.maxBank)))));
  }

  function subAssets(body, g) {
    const wagon = field('ui_adm_wagon');
    const card = el('div', 'card');
    card.appendChild(el('div', '', esc(t(g.hasWagon ? 'ui_adm_wagon_saved' : 'ui_adm_wagon_none'))));
    const actions = el('div', 'adm-inline');
    actions.append(button(t('ui_adm_wagon_here'), 'btn-small', () => act('setWagonHere', { name: g.name })));
    if (g.hasWagon) {
      actions.append(
        button(t('ui_adm_teleport'), 'btn-muted btn-small', () => act('teleport', { kind: 'wagon', name: g.name })),
        button(t('ui_adm_wagon_clear'), 'btn-muted btn-small', () => confirmAction(t('ui_adm_confirm_wagon', g.label), () => act('clearWagon', { name: g.name }))),
      );
    }
    card.appendChild(actions);
    wagon.appendChild(card);
    body.appendChild(wagon);

    const equip = field('ui_adm_equipment');
    const list = el('div', 'list');
    g.equipmentList.forEach((item) => {
      const r = el('div', 'list-row');
      r.appendChild(el('div', 'row-info', `<div class="row-title">${esc(item.label)}</div><div class="row-sub ${item.count ? 'ok' : ''}">${esc(t('ui_adm_deployed', item.count, item.max))}</div>`));
      list.appendChild(r);
    });
    equip.appendChild(list);
    const pack = button(t('ui_adm_pack_all'), 'btn-muted btn-small', () => confirmAction(t('ui_adm_confirm_pack', g.label), () => act('packEquipment', { name: g.name })));
    pack.disabled = !g.equipmentList.some((i) => i.count > 0);
    equip.appendChild(pack);
    body.appendChild(equip);

    if (S.snap.territories) {
      const turf = field('ui_adm_turf_owned');
      const tl = el('div', 'list');
      if (!g.territoryList.length) tl.appendChild(el('div', 'empty', esc(t('ui_adm_none_owned'))));
      g.territoryList.forEach((x) => {
        const r = el('div', 'list-row');
        r.appendChild(el('div', 'row-info', `<div class="row-title">${esc(x.label)}</div>`));
        const a = el('div', 'row-actions');
        a.append(
          button(t('ui_adm_teleport'), 'btn-muted btn-small', () => act('teleport', { kind: 'territory', id: x.id })),
          button(t('ui_adm_release'), 'btn-small', () => act('setTerritory', { id: x.id, gang: '' })),
        );
        r.appendChild(a);
        tl.appendChild(r);
      });
      turf.appendChild(tl);
      body.appendChild(turf);
    }

    const rivals = field('ui_adm_rivals');
    rivals.appendChild(button(t('ui_adm_clear_rivals'), 'btn-muted btn-small', () => confirmAction(t('ui_adm_confirm_rivals', g.label), () => act('clearRivals', { name: g.name }))));
    body.appendChild(rivals);
  }

  function subLog(body) {
    const list = el('div', 'list');
    if (!S.logs.length) list.appendChild(el('div', 'empty', esc(t('ui_adm_log_empty'))));
    S.logs.forEach((entry) => {
      const parts = (entry.detail || '').split('|');
      const key = 'log_' + entry.action;
      const text = L[key] != null ? t(key, ...parts) : entry.action;
      const r = el('div', 'list-row');
      r.appendChild(el('div', 'row-info', `<div class="row-title">${esc(text)}</div>` + (entry.actor ? `<div class="row-sub">${esc(entry.actor)}</div>` : '')));
      r.appendChild(el('div', 'adm-log-time', esc(entry.ts ? new Date(entry.ts * 1000).toLocaleString() : '')));
      list.appendChild(r);
    });
    body.appendChild(list);
  }

  // ---------- Rendering: territories tab ----------
  function renderTerritories() {
    const wrap = $('admTerrList');
    wrap.innerHTML = '';
    const list = S.snap && S.snap.territories;
    if (!list) { wrap.appendChild(el('div', 'empty', esc(t('ui_adm_terr_disabled')))); return; }
    if (!list.length) { wrap.appendChild(el('div', 'empty', esc(t('ui_adm_none_owned')))); return; }
    const options = [{ value: '', label: t('ui_adm_unowned') }].concat(S.snap.gangs.map((g) => ({ value: g.name, label: g.label })));
    list.forEach((x) => {
      const r = el('div', 'list-row');
      let badges = '';
      if (x.raidBy) badges += `<span class="badge adm-badge-warn">${esc(t('ui_adm_raid_by', x.raidBy))}</span> `;
      if (x.protected) badges += `<span class="badge adm-badge-ok">${esc(t('ui_adm_protected'))}</span>`;
      r.appendChild(el('div', 'row-info',
        `<div class="row-title">${esc(x.label)}</div>` +
        `<div class="row-sub">${esc(t('ui_adm_terr_sub', fmtMoney(x.income), fmtMoney(x.claimCost)))}</div>` + (badges ? `<div>${badges}</div>` : '')));
      const actions = el('div', 'adm-member-actions');
      actions.appendChild(makeDd(options, x.owner || '', (gang) => act('setTerritory', { id: x.id, gang })));
      actions.appendChild(button(t('ui_adm_teleport'), 'btn-muted btn-small', () => act('teleport', { kind: 'territory', id: x.id })));
      r.appendChild(actions);
      wrap.appendChild(r);
    });
  }

  // ---------- Rendering: players tab ----------
  function renderPlayers() {
    const wrap = $('admPlayerList');
    wrap.innerHTML = '';
    const q = S.playerSearch.trim().toLowerCase();
    const players = S.players.filter((p) => !q || p.name.toLowerCase().includes(q) || String(p.id) === q || p.citizenid.toLowerCase().includes(q));
    if (!players.length) { wrap.appendChild(el('div', 'empty', esc(t('ui_adm_no_players')))); return; }
    players.forEach((p) => {
      const r = el('div', 'list-row');
      const where = p.gang ? `${p.gangLabel} · ${p.rankLabel}` : t('ui_adm_no_gang');
      r.appendChild(el('div', 'row-info',
        `<div class="row-title">[${esc(p.id)}] ${esc(p.name)}</div><div class="row-sub">${esc(p.citizenid)} · ${esc(where)}</div>`));
      if (p.gang) {
        r.appendChild(button(t('ui_adm_view_gang'), 'btn-muted btn-small', () => { switchTab('gangs'); selectGang(p.gang); }));
      } else {
        r.appendChild(button(t('ui_adm_add_to_gang'), 'btn-small', () => addToGangModal(p)));
      }
      wrap.appendChild(r);
    });
  }

  function addToGangModal(p) {
    const gangs = (S.snap && S.snap.gangs) || [];
    if (!gangs.length) { toast(t('ui_adm_no_gangs'), 'error'); return; }
    const joinRanks = (S.snap.ranks || []).filter((r) => !r.isLeader).map((r) => ({ value: r.name, label: r.label }));
    let gangDd, rankDd;
    openModal({
      title: t('ui_adm_add_to_gang'),
      text: `[${p.id}] ${p.name}`,
      okLabel: t('ui_adm_add'),
      build: (body) => {
        gangDd = makeDd(gangs.map((g) => ({ value: g.name, label: g.label })), '', null, { placeholder: t('ui_adm_pick_gang_short') });
        rankDd = makeDd(joinRanks, joinRanks.length ? joinRanks[0].value : '');
        body.append(gangDd, rankDd);
      },
      onOk: () => {
        if (!gangDd.dataset.value) { toast(t('ui_adm_pick_gang_short'), 'error'); return; }
        act('addMember', { name: gangDd.dataset.value, serverId: p.id, rank: rankDd.dataset.value });
      },
    });
  }

  // ---------- Create tab ----------
  function renderCreateSwatches() {
    const wrap = $('admCreateSwatches');
    if (!S.snap || wrap.childElementCount) return;
    const hex = $('admCreateColor');
    (S.snap.colors || []).forEach((c) => {
      const sw = el('div', 'swatch');
      sw.style.background = c;
      sw.addEventListener('click', () => {
        hex.value = c;
        wrap.querySelectorAll('.swatch').forEach((n) => n.classList.remove('selected'));
        sw.classList.add('selected');
      });
      wrap.appendChild(sw);
    });
  }

  $('admCreateBtn').addEventListener('click', async () => {
    const label = $('admCreateLabel').value.trim();
    if (!label) { toast(t('ui_adm_need_name'), 'error'); return; }
    const leader = $('admCreateLeader').value.trim();
    const res = await act('createGang', {
      label, name: $('admCreateId').value.trim(), color: $('admCreateColor').value.trim(), leader: leader || undefined,
    });
    if (res && res.ok) {
      ['admCreateLabel', 'admCreateId', 'admCreateLeader'].forEach((id) => { $(id).value = ''; });
      switchTab('gangs');
      if (res.name) selectGang(res.name);
    }
  });

  // ---------- Tabs, search, wiring ----------
  function switchTab(tab) {
    S.tab = tab;
    closeDd();
    view.querySelectorAll('.adm-tab').forEach((b) => b.classList.toggle('active', b.dataset.admTab === tab));
    view.querySelectorAll('.adm-page').forEach((p) => p.classList.toggle('active', p.id === 'adm-page-' + tab));
    if (tab === 'players') loadPlayers();
  }
  view.querySelectorAll('.adm-tab').forEach((b) => b.addEventListener('click', () => switchTab(b.dataset.admTab)));

  $('admSearch').addEventListener('input', (e) => { S.search = e.target.value; renderGangList(); });
  $('admPlayerSearch').addEventListener('input', (e) => { S.playerSearch = e.target.value; renderPlayers(); });
  $('admRefresh').addEventListener('click', () => { if (!busy) refresh(); });
  $('admClose').addEventListener('click', () => post('adminClose'));

  document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape' || !isOpen) return;
    if (!$('admModal').classList.contains('hidden')) closeModal();
    else if (openDd) closeDd();
    else post('adminClose');
  });

  // ---------- Messages from the game client ----------
  function applyTitles() {
    view.querySelectorAll('[data-i18n-title]').forEach((n) => { n.title = t(n.dataset.i18nTitle); });
  }

  function openPanel() {
    isOpen = true;
    window.rsgAdminOpen = true;
    ['noGangView', 'gangView', 'craftView'].forEach((id) => { const n = $(id); if (n) n.classList.add('hidden'); });
    app.classList.remove('hidden');
    view.classList.remove('hidden');
    S.snap = null;
    S.detail = null;
    S.selected = null;
    applyTitles();
    switchTab('gangs');
    renderDetail();
    refresh();
  }

  function closePanel() {
    isOpen = false;
    window.rsgAdminOpen = false;
    closeModal();
    closeDd();
    view.classList.add('hidden');
    app.classList.add('hidden');
  }

  window.addEventListener('message', (event) => {
    const { action, data } = event.data || {};
    if (action === 'locale') {
      L = data || {};
      applyTitles();
      if (isOpen && S.snap) { renderStats(); renderGangList(); renderDetail(); renderTerritories(); renderPlayers(); }
    } else if (action === 'adminOpen') {
      openPanel();
    } else if (action === 'adminClose') {
      closePanel();
    }
  });
})();
