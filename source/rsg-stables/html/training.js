// rsg-stables: horse training NUI (timing minigame)
(function () {
  const res = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'rsg-stables';
  const post = (name, data) => fetch(`https://${res}/${name}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data || {}),
  }).then((r) => r.json()).catch(() => ({}));

  const $ = (id) => document.getElementById(id);
  const modal = $('trainingModal'), list = $('trainingList'), note = $('trainingNote');
  const game = $('trainingGame'), roundEl = $('trainingRound'), zone = $('trainingZone');
  const marker = $('trainingMarker'), feedback = $('trainingFeedback'), hintEl = $('trainingHint');
  const closeBtn = $('trainingCloseBtn');

  let S = {};           // locale strings
  let order = [];
  let state = null;     // current training data
  let run = null;       // running minigame
  let cooldownTimer = null;

  const t = (k, ...a) => { let s = S[k] !== undefined ? String(S[k]) : k; a.forEach((v) => { s = s.replace('%s', v); }); return s; };

  function render() {
    list.innerHTML = '';
    game.classList.add('hidden');
    list.classList.remove('hidden');
    const left = state.cooldownLeft || 0;
    note.classList.toggle('hidden', left <= 0);
    if (left > 0) note.textContent = t('training_cooldown_ui', Math.ceil(left / 60));

    order.forEach((key) => {
      const s = state.stats[key];
      const row = document.createElement('div');
      row.className = 'training-row';
      const info = document.createElement('div');
      info.className = 'training-info';
      const top = document.createElement('div');
      top.className = 'stat-row-top';
      top.innerHTML = `<span class="stat-label"></span><span class="stat-value"></span>`;
      top.children[0].textContent = t('training_' + key);
      top.children[1].textContent = t('training_level', s.level, state.maxLevel);
      info.appendChild(top);

      const maxed = !s.nextXp;
      const pct = maxed ? 100 : Math.max(0, Math.min(100, ((s.xp - s.prevXp) / (s.nextXp - s.prevXp)) * 100));
      const track = document.createElement('div');
      track.className = 'stat-bar-track';
      const fill = document.createElement('div');
      fill.className = 'stat-bar-fill ' + (maxed ? 'stat-good' : 'stat-warn');
      fill.style.width = pct + '%';
      track.appendChild(fill);
      info.appendChild(track);

      const xp = document.createElement('div');
      xp.className = 'training-xp';
      xp.textContent = maxed ? t('training_maxed') : `${s.xp} / ${s.nextXp} XP`;
      info.appendChild(xp);
      row.appendChild(info);

      const btn = document.createElement('button');
      btn.className = 'wood-btn';
      btn.textContent = t('training_train_btn', (state.prices && state.prices[key]) || 0);
      btn.disabled = maxed || left > 0;
      btn.addEventListener('click', () => start(key));
      row.appendChild(btn);
      list.appendChild(row);
    });
  }

  async function start(stat) {
    if (run) return;
    list.querySelectorAll('button').forEach((b) => { b.disabled = true; });
    const r = await post('trainingStart', { stat });
    if (!r || !r.ok) { render(); return; }
    list.classList.add('hidden');
    note.classList.add('hidden');
    game.classList.remove('hidden');
    hintEl.textContent = t('training_hint');
    run = { rounds: r.rounds, roundMs: r.roundMs, round: 0, hits: 0 };
    nextRound();
  }

  function nextRound() {
    if (!run) return;
    if (run.round >= run.rounds) { finish(); return; }
    run.round += 1;
    run.pressed = false;
    roundEl.textContent = t('training_round', run.round, run.rounds);
    feedback.textContent = '';
    feedback.className = 'training-feedback';
    const width = Math.max(10, 22 - run.round * 2);      // zone narrows each round
    run.zoneFrom = 15 + Math.random() * (70 - width);
    run.zoneTo = run.zoneFrom + width;
    zone.style.left = run.zoneFrom + '%';
    zone.style.width = width + '%';
    run.started = performance.now();
    const step = (now) => {
      if (!run) return;
      const p = Math.min(1, (now - run.started) / run.roundMs);
      run.pos = p * 100;
      marker.style.left = run.pos + '%';
      if (p < 1) { run.raf = requestAnimationFrame(step); return; }
      if (!run.pressed) showResult(false);
      setTimeout(nextRound, 400);
    };
    run.raf = requestAnimationFrame(step);
  }

  function showResult(hit) {
    feedback.textContent = hit ? t('training_hit') : t('training_miss');
    feedback.className = 'training-feedback ' + (hit ? 'hit' : 'miss');
  }

  function press() {
    if (!run || run.pressed || run.pos === undefined) return;
    run.pressed = true;
    const hit = run.pos >= run.zoneFrom && run.pos <= run.zoneTo;
    if (hit) run.hits += 1;
    showResult(hit);
  }

  async function finish() {
    const hits = run ? run.hits : 0;
    run = null;
    const r = await post('trainingFinish', { hits });
    if (r && r.ok && r.data) state = r.data;
    render();
  }

  function close() {
    if (run) { cancelAnimationFrame(run.raf); const hits = run.hits; run = null; post('trainingFinish', { hits }); }
    if (cooldownTimer) { clearInterval(cooldownTimer); cooldownTimer = null; }
    modal.classList.add('hidden');
    post('trainingClose');
  }

  closeBtn.addEventListener('click', close);
  game.addEventListener('mousedown', press);
  document.addEventListener('keydown', (e) => {
    if (modal.classList.contains('hidden')) return;
    if (e.code === 'Space') { e.preventDefault(); press(); }
    if (e.key === 'Escape') close();
  });

  window.addEventListener('message', (event) => {
    const d = event.data;
    if (!d) return;
    if (d.action === 'trainingOpen') {
      S = Object.assign({}, d.strings || {});
      order = d.order || [];
      state = d.data;
      $('trainingTitle').textContent = t('training_title');
      $('trainingHorse').textContent = state.name || '';
      closeBtn.textContent = t('ui_close');
      modal.classList.remove('hidden');
      render();
      if (cooldownTimer) clearInterval(cooldownTimer);
      cooldownTimer = setInterval(() => {
        if (!state || run || !(state.cooldownLeft > 0)) return;
        state.cooldownLeft = Math.max(0, state.cooldownLeft - 1);
        if (state.cooldownLeft % 60 === 0) render();
      }, 1000);
    } else if (d.action === 'trainingClose') {
      if (run) { cancelAnimationFrame(run.raf); run = null; }
      modal.classList.add('hidden');
    }
  });
})();
