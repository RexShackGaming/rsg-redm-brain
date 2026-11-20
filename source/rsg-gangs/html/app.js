(function () {
  const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-gangs';
  const $ = (id) => document.getElementById(id);

  const app = $('app');
  const views = { none: $('noGangView'), gang: $('gangView'), craft: $('craftView') };

  let L = {};          // locale dictionary pushed by the client
  let state = { inGang: false };
  let activeView = null;
  let craftData = null;

  function post(endpoint, data) {
    return fetch(`https://${RESOURCE}/${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).catch(() => {});
  }

  // t('key', a, b) fills %s / %d in order
  function t(key, ...args) {
    let text = L[key] != null ? String(L[key]) : key;
    let i = 0;
    return text.replace(/%[sd]/g, () => (i < args.length ? args[i++] : ''));
  }

  function fmtMoney(n) { return '$' + (Number(n) || 0).toLocaleString('en-US'); }

  function esc(value) {
    const div = document.createElement('div');
    div.textContent = value == null ? '' : String(value);
    return div.innerHTML;
  }

  function applyLocale() {
    document.querySelectorAll('[data-i18n]').forEach((el) => { el.textContent = t(el.dataset.i18n); });
    document.querySelectorAll('[data-i18n-placeholder]').forEach((el) => { el.placeholder = t(el.dataset.i18nPlaceholder); });
  }

  function showView(name) {
    activeView = name;
    Object.entries(views).forEach(([key, el]) => el.classList.toggle('hidden', key !== name));
  }

  // ---------- In-UI toast (client-side validation only; server messages use rsg-core notify) ----------
  function toast(message, type) {
    const el = document.createElement('div');
    el.className = 'toast ' + (type || '');
    el.textContent = message;
    $('toasts').appendChild(el);
    setTimeout(() => el.remove(), 3000);
  }

  // ---------- Confirm modal ----------
  let modalAction = null;
  function confirmAction(title, text, onOk) {
    $('modalTitle').textContent = title;
    $('modalText').textContent = text;
    modalAction = onOk;
    $('modal').classList.remove('hidden');
  }
  function closeModal() {
    $('modal').classList.add('hidden');
    modalAction = null;
  }
  $('modalCancel').addEventListener('click', closeModal);
  $('modalOk').addEventListener('click', () => {
    const action = modalAction;
    closeModal();
    if (action) action();
  });

  // ---------- Submit lock: a click is ignored until the server answers (fresh state) ----------
  const pending = new Set();
  function lockAndPost(btn, endpoint, data) {
    if (btn && btn.disabled) return;
    if (btn) { btn.disabled = true; pending.add(btn); }
    post(endpoint, data);
  }
  function releasePending() {
    pending.forEach((btn) => { btn.disabled = false; });
    pending.clear();
  }
  setInterval(() => { if (pending.size > 0) releasePending(); }, 4000);

  // ---------- Static wiring ----------
  document.querySelectorAll('[data-close]').forEach((el) => el.addEventListener('click', () => post('close')));

  document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    if (!$('modal').classList.contains('hidden')) closeModal();
    else post('close');
  });

  document.querySelectorAll('.tab-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.tab-btn').forEach((b) => b.classList.remove('active'));
      document.querySelectorAll('.tab-content').forEach((c) => c.classList.remove('active'));
      btn.classList.add('active');
      $('tab-' + btn.dataset.tab).classList.add('active');
      if (btn.dataset.tab === 'log') post('requestLogs');
      if (btn.dataset.tab === 'top') post('requestLeaderboard');
    });
  });

  // Draggable panels
  (function enableDrag() {
    let dragging = false, startX = 0, startY = 0, startLeft = 0, startTop = 0, positioned = false;
    const host = document.getElementById('app');

    document.querySelectorAll('.panel-header').forEach((header) => {
      header.addEventListener('mousedown', (e) => {
        if (e.target.closest('[data-close]')) return;
        dragging = true;
        const panel = header.closest('.panel');
        const rect = panel.getBoundingClientRect();
        if (!positioned) {
          host.style.alignItems = 'flex-start';
          host.style.justifyContent = 'flex-start';
          positioned = true;
        }
        panel.style.position = 'absolute';
        panel.style.left = rect.left + 'px';
        panel.style.top = rect.top + 'px';
        startLeft = rect.left; startTop = rect.top; startX = e.clientX; startY = e.clientY;
        header._panel = panel;
        document._dragPanel = panel;
        e.preventDefault();
      });
    });
    document.addEventListener('mousemove', (e) => {
      if (!dragging || !document._dragPanel) return;
      const p = document._dragPanel;
      const left = Math.max(0, Math.min(startLeft + e.clientX - startX, window.innerWidth - p.offsetWidth));
      const top = Math.max(0, Math.min(startTop + e.clientY - startY, window.innerHeight - p.offsetHeight));
      p.style.left = left + 'px';
      p.style.top = top + 'px';
    });
    document.addEventListener('mouseup', () => { dragging = false; });
  })();

  // ---------- Rendering ----------
  function rankWeight(rankName, ranks) {
    const r = (ranks || []).find((x) => x.name === rankName);
    return r ? r.weight : -1;
  }

  function row(titleHtml, subHtml, actions) {
    const el = document.createElement('div');
    el.className = 'list-row';
    const info = document.createElement('div');
    info.className = 'row-info';
    info.innerHTML = `<div class="row-title">${titleHtml}</div>${subHtml ? `<div class="row-sub">${subHtml}</div>` : ''}`;
    el.appendChild(info);
    if (actions && actions.childNodes.length) el.appendChild(actions);
    return el;
  }

  function actionButton(label, className, onClick, tooltip) {
    const b = document.createElement('button');
    b.className = 'btn btn-small ' + (className || '');
    b.textContent = label;
    if (tooltip) b.title = tooltip;
    b.addEventListener('click', onClick);
    return b;
  }

  function render() {
    if (activeView === 'craft') return; // a state broadcast must not close an open crafting view

    if (!state.inGang) {
      showView('none');
      $('createCostTag').textContent = state.createCost > 0 ? `(${fmtMoney(state.createCost)})` : '';
      if (state.maxNameLength) $('gangLabelInput').maxLength = state.maxNameLength;
      return;
    }

    showView('gang');
    const gang = state.gang;
    const perms = state.myPermissions || [];
    const has = (p) => perms.includes(p);
    const myRank = (gang.ranks || []).find((r) => r.name === state.myRank) || {};
    const myWeight = myRank.weight != null ? myRank.weight : -1;

    $('gangLabel').textContent = (gang.tag ? `[${gang.tag}] ` : '') + gang.label;
    $('tagBlock').classList.toggle('hidden', !(has('rename') && state.tagsEnabled));
    $('tabBtnTop').classList.toggle('hidden', !state.leaderboardEnabled);
    $('gangColorDot').style.background = gang.color;
    $('gangColorDot').style.boxShadow = `0 0 10px 1px ${gang.color}88`;

    // Overview
    const max = gang.maxMembers > 0 ? ` / ${gang.maxMembers}` : '';
    $('statMembers').textContent = gang.members.length + max;
    $('statBank').textContent = fmtMoney(gang.bank);
    $('statRank').textContent = myRank.label || state.myRank || '-';
    $('disbandGangBtn').classList.toggle('hidden', !has('disband'));
    $('leaveGangBtn').classList.toggle('hidden', !!myRank.isLeader && gang.members.length > 1);
    $('wagonResetBlock').classList.toggle('hidden', !(has('equipment') && gang.hasWagon));

    renderMembers(gang, has, myWeight, !!myRank.isLeader);

    // Bank
    $('bankAmount').textContent = fmtMoney(gang.bank);
    $('withdrawRow').classList.toggle('hidden', !has('withdraw'));

    renderEquipment(gang.equipment || [], has('equipment'));
    renderTurf(gang.territories, has('upgrade'));
    renderUpkeep(gang.upkeep);
    renderBounty(gang.bounties, has('bounty'));
    renderRivals(gang.rivals);
    $('honorCard').classList.toggle('hidden', gang.honor == null);
    if (gang.honor != null) $('statHonor').textContent = gang.honor;
    renderBlipBtn();
    const canLog = !!state.canViewLog;
    $('tagInput').placeholder = gang.tag || '';
    $('tabBtnLog').classList.toggle('hidden', !canLog);
    renderStash(gang.stashTiers || [], has('upgrade'));

    // Settings
    $('renameBlock').classList.toggle('hidden', !has('rename'));
    $('colorBlock').classList.toggle('hidden', !has('setcolor'));
    renderSwatches(gang.color);
  }

  function renderMembers(gang, has, myWeight, isLeader) {
    $('inviteRow').classList.toggle('hidden', !has('invite'));
    const list = $('memberList');
    list.innerHTML = '';
    if (!gang.members.length) { list.innerHTML = `<div class="empty">${esc(t('ui_no_members'))}</div>`; return; }

    gang.members.forEach((m) => {
      const title = `<span class="member-line"><span class="dot ${m.online ? 'online' : ''}" title="${esc(t(m.online ? 'ui_online' : 'ui_offline'))}"></span>${esc(m.name)}</span>`;
      const actions = document.createElement('div');
      actions.className = 'row-actions';
      const isMe = m.citizenid === state.citizenid;
      const lower = m.weight < myWeight;

      if (!isMe && lower && has('promote')) actions.appendChild(actionButton('↑', 'btn-muted', () => post('promoteMember', { citizenid: m.citizenid }), t('ui_promote')));
      if (!isMe && lower && has('demote')) actions.appendChild(actionButton('↓', 'btn-muted', () => post('demoteMember', { citizenid: m.citizenid }), t('ui_demote')));
      if (!isMe && isLeader) {
        actions.appendChild(actionButton(t('ui_make_leader'), 'btn-muted', () =>
          confirmAction(t('ui_make_leader'), t('ui_confirm_transfer', m.name), () => post('transferLeadership', { citizenid: m.citizenid }))));
      }
      if (!isMe && lower && has('kick')) {
        actions.appendChild(actionButton(t('ui_kick'), 'btn-danger', () =>
          confirmAction(t('ui_kick'), t('ui_confirm_kick', m.name), () => post('kickMember', { citizenid: m.citizenid }))));
      }

      list.appendChild(row(title, `<span class="badge">${esc(m.rankLabel)}</span>`, actions));
    });
  }

  function renderTurf(list, canManage) {
    $('tabBtnTurf').classList.toggle('hidden', !list);
    const wrap = $('turfList');
    wrap.innerHTML = '';
    (list || []).forEach((tr) => {
      const status = tr.mine ? t('ui_turf_yours') : (tr.owner ? t('ui_turf_held_by', tr.ownerLabel || tr.owner) + (tr.ownerHonor != null ? ' (' + t('ui_gang_honor') + ' ' + tr.ownerHonor + ')' : '') : t('ui_turf_free'));
      const sub = `${esc(status)} &middot; ${esc(t('ui_turf_income', fmtMoney(tr.income)))}` + (!tr.owner ? ` &middot; ${esc(t('ui_turf_cost', fmtMoney(tr.claimCost)))}` : '');
      let sub2 = '';
      const actions = document.createElement('div');
      actions.className = 'row-actions';
      if (canManage && !tr.owner) {
        const b = actionButton(t('ui_turf_claim'), '', () => lockAndPost(b, 'claimTerritory', { id: tr.id }));
        actions.appendChild(b);
      } else if (canManage && tr.mine) {
        const b = actionButton(t('ui_turf_abandon'), 'btn-muted', () => confirmAction(t('ui_turf_abandon'), t('ui_turf_abandon_confirm', tr.label), () => lockAndPost(b, 'abandonTerritory', { id: tr.id })));
        actions.appendChild(b);
      }
      if (canManage && tr.owner && !tr.mine && tr.raidable) {
        if (tr.raidBy) {
          sub2 = ` &middot; ${esc(t('ui_turf_raiding', tr.raidBy))}`;
        } else if (tr.protected) {
          sub2 = ` &middot; ${esc(t('ui_turf_protected'))}`;
        } else {
          const rb = actionButton(t('ui_turf_raid'), '', () => confirmAction(t('ui_turf_raid'), t('ui_turf_raid_confirm', tr.label), () => lockAndPost(rb, 'startRaid', { id: tr.id })));
          actions.appendChild(rb);
        }
      } else if (tr.raidBy) {
        sub2 = ` &middot; ${esc(t('ui_turf_raiding', tr.raidBy))}`;
      }
      wrap.appendChild(row(esc(tr.label), sub + sub2, actions));
    });
  }

  let blipsOn = true;
  function renderBlipBtn() { $('blipBtn').textContent = blipsOn ? t('ui_blips_hide') : t('ui_blips_show'); }
  $('blipBtn').addEventListener('click', () => { post('setBlips', { enabled: !blipsOn }); });
  $('tagBtn').addEventListener('click', (e) => { lockAndPost(e.currentTarget, 'setTag', { tag: $('tagInput').value.trim() }); $('tagInput').value = ''; });

  function renderTop(data) {
    const rows = (data && data.rows) || [];
    $('topLede').textContent = t('ui_top_lede', (data && data.season) || '');
    const wrap = $('topList');
    wrap.innerHTML = '';
    rows.forEach((r, i) => {
      const name = `${i + 1}. ${r.tag ? '[' + esc(r.tag) + '] ' : ''}${esc(r.label)}`;
      wrap.appendChild(row(name, esc(t('ui_top_row', r.score, r.turf, r.kills))));
    });
  }

  function renderBounty(b, canPost) {
    $('tabBtnBounty').classList.toggle('hidden', !b);
    if (!b) return;
    $('bountyLede').textContent = t('ui_bounty_lede', fmtMoney(b.min), fmtMoney(b.max));
    $('bountyCard').textContent = b.active > 0 ? t('ui_bounty_active', b.active, fmtMoney(b.total)) : t('ui_bounty_none');
    $('bountyRow').classList.toggle('hidden', !canPost);
  }

  $('bountyBtn').addEventListener('click', (e) => {
    const amount = amountOf('bountyInput');
    if (amount == null) return;
    lockAndPost(e.currentTarget, 'postBounty', { amount });
    $('bountyInput').value = '';
  });

  function renderRivals(list) {
    $('rivalsBlock').classList.toggle('hidden', !list || !list.length);
    const wrap = $('rivalsList');
    wrap.innerHTML = '';
    (list || []).forEach((r) => wrap.appendChild(row(esc(r.label), esc(t('ui_rival_row', r.kills, r.deaths)))));
  }

  function renderUpkeep(u) {
    $('upkeepBlock').classList.toggle('hidden', !u);
    if (!u) return;
    const due = u.due ? new Date(u.due * 1000).toLocaleString() : '-';
    $('upkeepCard').innerHTML = `<div>${esc(t('ui_upkeep_cost', fmtMoney(u.cost)))}</div><div class="row-sub">${esc(t('ui_upkeep_due', due))}</div>` +
      (u.missed > 0 ? `<div class="row-sub warn">${esc(t('ui_upkeep_missed', u.missed, u.maxMissed))}</div>` : '');
  }

  function renderLog(rows) {
    const wrap = $('logList');
    wrap.innerHTML = '';
    if (!rows.length) { wrap.innerHTML = `<div class="empty">${esc(t('ui_log_empty'))}</div>`; return; }
    rows.forEach((r) => {
      const args = String(r.detail || '').split('|');
      const text = t('log_' + r.action, ...args);
      const who = r.actor ? esc(r.actor) + ' &middot; ' : '';
      wrap.appendChild(row(esc(text), who + esc(new Date(r.ts * 1000).toLocaleString())));
    });
  }

  function renderEquipment(items, canManage) {
    const wrap = $('equipmentList');
    wrap.innerHTML = '';
    if (!items.length) { wrap.innerHTML = `<div class="empty">${esc(t('ui_no_equipment'))}</div>`; return; }

    items.forEach((item) => {
      const atMax = item.deployedCount >= item.maxDeployed;
      const none = item.deployedCount <= 0;
      const sub = `<span class="${none ? '' : 'ok'}">${esc(t('ui_deployed_count', item.deployedCount, item.maxDeployed))}</span>`;
      const actions = document.createElement('div');
      actions.className = 'row-actions';

      if (canManage) {
        const setUp = actionButton(t('ui_set_up'), '', () => lockAndPost(setUp, 'deployEquipment', { id: item.id }), atMax ? t('ui_max_deployed_tip', item.maxDeployed) : '');
        setUp.disabled = atMax;
        const pack = actionButton(t('ui_pack_away'), 'btn-muted', () => lockAndPost(pack, 'packEquipment', { id: item.id }));
        pack.disabled = none;
        actions.appendChild(setUp);
        actions.appendChild(pack);
      }
      wrap.appendChild(row(esc(item.label), sub, actions));
    });
  }

  function renderStash(tiers, canUpgrade) {
    const wrap = $('stashTierCard');
    wrap.innerHTML = '';
    if (!tiers.length) { wrap.innerHTML = `<div class="empty">${esc(t('ui_storage_not_configured'))}</div>`; return; }

    const current = tiers.find((x) => x.isCurrent) || tiers[0];
    const next = tiers.find((x) => x.isNext);
    const kg = Math.round((current.maxWeight || 0) / 1000);

    const info = document.createElement('div');
    info.className = 'row-info';
    info.innerHTML = `<div class="row-title">${esc(current.label)}</div><div class="row-sub">${esc(t('ui_slots_weight', current.slots, kg))}</div>`;
    wrap.appendChild(info);

    if (!next) {
      const done = document.createElement('div');
      done.className = 'row-sub';
      done.textContent = t('ui_max_tier');
      wrap.appendChild(done);
      return;
    }

    const btn = actionButton(t('ui_upgrade_to', next.label, fmtMoney(next.upgradeCost)), '', () =>
      confirmAction(t('ui_upgrade'), t('ui_confirm_upgrade', next.label, fmtMoney(next.upgradeCost)), () => lockAndPost(btn, 'upgradeGangStash')));
    btn.disabled = !canUpgrade || !next.canAfford;
    btn.title = !canUpgrade ? t('ui_no_upgrade_permission') : (!next.canAfford ? t('ui_not_enough_funds') : '');
    wrap.appendChild(btn);
  }

  function renderSwatches(selected) {
    const wrap = $('colorSwatches');
    wrap.innerHTML = '';
    (state.colors || []).forEach((color) => {
      const sw = document.createElement('div');
      sw.className = 'swatch' + (color === selected ? ' selected' : '');
      sw.style.background = color;
      sw.addEventListener('click', () => post('setColor', { color }));
      wrap.appendChild(sw);
    });
  }

  // ---------- Crafting ----------
  function renderCraft() {
    if (!craftData) return;
    $('craftStationLabel').textContent = craftData.label || t('ui_crafting');
    $('craftIntro').textContent = craftData.intro || '';

    const wrap = $('craftRecipeList');
    wrap.innerHTML = '';
    const recipes = craftData.recipes || [];
    if (!recipes.length) { wrap.innerHTML = `<div class="empty">${esc(t('ui_no_recipes'))}</div>`; return; }

    recipes.forEach((recipe) => {
      const ingredients = (recipe.ingredients || []).map((i) => `${i.amount}x ${i.item}`).join(', ');
      const actions = document.createElement('div');
      actions.className = 'row-actions';
      const btn = actionButton(t('ui_craft'), '', () => lockAndPost(btn, 'craftItem', { stationId: craftData.stationId, id: recipe.id }));
      actions.appendChild(btn);
      wrap.appendChild(row(esc(recipe.label), esc(ingredients), actions));
    });
  }

  // ---------- Actions ----------
  $('createGangBtn').addEventListener('click', (e) => {
    const label = $('gangLabelInput').value.trim();
    if (!label) return;
    lockAndPost(e.currentTarget, 'createGang', { label });
  });

  $('leaveGangBtn').addEventListener('click', () =>
    confirmAction(t('ui_leave'), t('ui_confirm_leave'), () => lockAndPost($('leaveGangBtn'), 'leaveGang')));
  $('disbandGangBtn').addEventListener('click', () =>
    confirmAction(t('ui_disband'), t('ui_confirm_disband'), () => lockAndPost($('disbandGangBtn'), 'disbandGang')));
  $('resetWagonBtn').addEventListener('click', (e) => lockAndPost(e.currentTarget, 'resetWagon'));

  $('inviteBtn').addEventListener('click', (e) => {
    const id = parseInt($('inviteInput').value, 10);
    if (!Number.isInteger(id) || id <= 0) { toast(t('ui_invalid_id'), 'error'); return; }
    lockAndPost(e.currentTarget, 'invitePlayer', { serverId: id });
    $('inviteInput').value = '';
  });

  function amountOf(inputId) {
    const n = Number($(inputId).value);
    if (!Number.isInteger(n) || n <= 0) { toast(t('ui_invalid_amount'), 'error'); return null; }
    return n;
  }

  $('depositBtn').addEventListener('click', (e) => {
    const amount = amountOf('depositInput');
    if (amount == null) return;
    lockAndPost(e.currentTarget, 'depositMoney', { amount });
    $('depositInput').value = '';
  });

  $('withdrawBtn').addEventListener('click', (e) => {
    const amount = amountOf('withdrawInput');
    if (amount == null) return;
    lockAndPost(e.currentTarget, 'withdrawMoney', { amount });
    $('withdrawInput').value = '';
  });

  $('renameBtn').addEventListener('click', (e) => {
    const label = $('renameInput').value.trim();
    if (!label) return;
    lockAndPost(e.currentTarget, 'renameGang', { label });
    $('renameInput').value = '';
  });

  // ---------- Messages from the game client ----------
  window.addEventListener('message', (event) => {
    const { action, data } = event.data || {};

    if (action === 'locale') {
      L = data || {};
      applyLocale();
      if (activeView === 'craft') renderCraft();
    } else if (action === 'open') {
      app.classList.remove('hidden');
      craftData = null;
      activeView = null;
      render();
    } else if (action === 'openCraft') {
      craftData = data || {};
      app.classList.remove('hidden');
      showView('craft');
      renderCraft();
    } else if (action === 'close') {
      app.classList.add('hidden');
      closeModal();
      craftData = null;
      activeView = null;
      releasePending();
    } else if (action === 'blips') {
      blipsOn = data !== false;
      renderBlipBtn();
    } else if (action === 'leaderboard') {
      renderTop(data);
    } else if (action === 'logs') {
      renderLog(Array.isArray(data) ? data : []);
    } else if (action === 'state') {
      state = data || { inGang: false };
      render();
      releasePending();
    }
  });
})();
