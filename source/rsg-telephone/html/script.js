const $ = id => document.getElementById(id);
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-telephone';
const post = (ev, data = {}) => fetch(`https://${RES}/${ev}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) }).then(r => r.json()).catch(() => null);

let state = 'idle';   // idle | dialling | ringing | connected | ended
let digits = '';
let directory = [];
let isAdmin = false;
let pay = null, credit = 0; // payphone (credit in cents)
let timerInt = null;
let T = {}; // filled from locales/*.json on open
const fmt = (s, v) => String(s ?? '').replace('%s', v ?? '');
function applyText(ui) {
  if (ui) T = { ...T, ...ui };
  document.querySelector('.title').textContent = T.title;
  $('callBtn').textContent = T.call; $('endBtn').textContent = T.end_call;
  $('search').placeholder = T.search; $('tabBtn').title = T.directory; $('closeBtn').title = T.close;
  document.querySelector('.key[data-k="clear"]').textContent = T.clear;
}

/* ---------------- audio (WebAudio, no sound files) — antique line ---------------- */
let ctx = null, lineBus = null;
const ac = () => (ctx = ctx || new (window.AudioContext || window.webkitAudioContext)());

// everything heard "down the line" goes through a narrow, slightly overdriven band like an old carbon earpiece
function line() {
  if (lineBus) return lineBus;
  const a = ac(), hp = a.createBiquadFilter(), lp = a.createBiquadFilter(), sh = a.createWaveShaper();
  hp.type = 'highpass'; hp.frequency.value = 300; lp.type = 'lowpass'; lp.frequency.value = 2600; lp.Q.value = 2;
  const c = new Float32Array(256); for (let i = 0; i < 256; i++) { const x = i / 128 - 1; c[i] = Math.tanh(2.2 * x); }
  sh.curve = c; hp.connect(sh); sh.connect(lp); lp.connect(a.destination);
  return (lineBus = hp);
}
function noise(a, dur) {
  const b = a.createBuffer(1, Math.ceil(a.sampleRate * dur), a.sampleRate), d = b.getChannelData(0);
  for (let i = 0; i < d.length; i++) d[i] = (Math.random() * 2 - 1) * (Math.random() < 0.002 ? 4 : 1); // hiss + crackle pops
  const s = a.createBufferSource(); s.buffer = b; return s;
}

// ringback heard by the caller: old buzzy "brrr" — low tone chopped by a ~20Hz tremolo, with line hiss
let ringback = null, hiss = null;
function startRingback() {
  stopRingback();
  const a = ac();
  hiss = noise(a, 2); hiss.loop = true; const hg = a.createGain(); hg.gain.value = 0.012;
  hiss.connect(hg); hg.connect(line()); hiss.start();
  const tick = () => {
    const t = a.currentTime, g = a.createGain(), trem = a.createGain(), lfo = a.createOscillator(), lfoAmt = a.createGain();
    const o1 = a.createOscillator(), o2 = a.createOscillator();
    o1.type = 'sawtooth'; o1.frequency.value = 133; o2.type = 'square'; o2.frequency.value = 400;
    const m2 = a.createGain(); m2.gain.value = 0.25;
    lfo.frequency.value = 20; lfoAmt.gain.value = 0.5; trem.gain.value = 0.5;
    lfo.connect(lfoAmt); lfoAmt.connect(trem.gain);
    g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(0.09, t + 0.04);
    g.gain.setValueAtTime(0.09, t + 1.6); g.gain.linearRampToValueAtTime(0, t + 1.7);
    o1.connect(trem); o2.connect(m2); m2.connect(trem); trem.connect(g); g.connect(line());
    [o1, o2, lfo].forEach(o => { o.start(t); o.stop(t + 1.75); });
  };
  tick(); ringback = setInterval(tick, 4500);
}
function stopRingback() {
  if (ringback) { clearInterval(ringback); ringback = null; }
  if (hiss) { try { hiss.stop(); } catch (e) {} hiss = null; }
}

// mechanical bell: a clapper hammering two brass gongs ~18 times a second; inharmonic partials + decay
const bells = {};
let bellLoop = null;
const GONGS = [[1, 2.76, 5.4, 8.93], [1, 2.7, 5.2, 8.6]];
// one bus for the bell: gain (distance) -> lowpass (walls) -> stereo pan (direction); smoothed so it never jumps
let bellBus = null;
function bus() {
  if (bellBus) return bellBus;
  const a = ac(), g = a.createGain(), lp = a.createBiquadFilter(), pan = a.createStereoPanner ? a.createStereoPanner() : null;
  g.gain.value = 0; lp.type = 'lowpass'; lp.frequency.value = 12000;
  g.connect(lp); if (pan) { lp.connect(pan); pan.connect(a.destination); } else lp.connect(a.destination);
  return (bellBus = { input: g, gain: g, lp, pan });
}
function applyBell() {
  const live = Object.values(bells); if (!live.length) return;
  const b = live.reduce((x, y) => (y.volume > x.volume ? y : x)); // loudest phone wins
  const a = ac(), t = a.currentTime, B = bus();
  B.gain.gain.setTargetAtTime(b.muffled ? b.volume * 0.55 : b.volume, t, 0.08);
  B.lp.frequency.setTargetAtTime(b.muffled ? 900 : 12000, t, 0.12);
  if (B.pan) B.pan.pan.setTargetAtTime(Math.max(-1, Math.min(1, b.pan || 0)), t, 0.08);
}
function strike(a, t, base, partials, vol) {
  const out = a.createGain(); out.gain.value = vol; out.connect(bus().input);
  partials.forEach((r, i) => {
    const o = a.createOscillator(), g = a.createGain();
    o.frequency.value = base * r; o.detune.value = (Math.random() - 0.5) * 8;
    const amp = 0.22 / (i + 1), decay = 0.35 / (i * 0.8 + 1);
    g.gain.setValueAtTime(amp, t); g.gain.exponentialRampToValueAtTime(0.0001, t + decay);
    o.connect(g); g.connect(out); o.start(t); o.stop(t + decay + 0.02);
  });
  // the metal "tick" of the hammer
  const n = noise(a, 0.015), ng = a.createGain(), bp = a.createBiquadFilter();
  bp.type = 'bandpass'; bp.frequency.value = 4500; ng.gain.value = 0.15;
  n.connect(bp); bp.connect(ng); ng.connect(out); n.start(t);
}
function bellBurst(vol) {
  const a = ac(), t0 = a.currentTime;
  for (let i = 0; i < 34; i++) {           // ~1.9s of ringing
    const left = i % 2 === 0;
    strike(a, t0 + i * 0.055, left ? 880 : 932, GONGS[left ? 0 : 1], vol * (0.85 + Math.random() * 0.15));
  }
}
function updateBells() {
  const any = Object.keys(bells).length > 0;
  if (any) applyBell();
  if (any && !bellLoop) {
    const play = () => { if (Object.keys(bells).length) bellBurst(1); };
    play(); bellLoop = setInterval(play, 4000);   // long ring, pause, long ring
  } else if (!any && bellLoop) {
    clearInterval(bellLoop); bellLoop = null;
    if (bellBus) bellBus.gain.gain.setTargetAtTime(0, ac().currentTime, 0.05);
  }
}

// keypad: rotary-style pulse clicks (1 = one click ... 0 = ten clicks)
function dialClick(k) {
  const n = k === '0' ? 10 : parseInt(k, 10); if (!n) return;
  const a = ac(), t0 = a.currentTime;
  for (let i = 0; i < n; i++) {
    const s = noise(a, 0.012), g = a.createGain(), bp = a.createBiquadFilter();
    bp.type = 'bandpass'; bp.frequency.value = 1800; bp.Q.value = 3; g.gain.value = 0.35;
    s.connect(bp); bp.connect(g); g.connect(a.destination); s.start(t0 + i * 0.06);
  }
}

/* ---------------- UI ---------------- */
function setStatus(text, cls = '') { const s = $('status'); s.textContent = text; s.className = 'status ' + cls; }
function render() {
  $('number').textContent = digits || ' ';
  $('callBtn').disabled = state !== 'idle' || digits.length < 2 || (pay && credit < Math.round(pay.cost * 100));
  document.querySelectorAll('#coins .coin.ret').forEach(c => c.disabled = state !== 'idle');
  if (typeof refreshCoins === 'function') refreshCoins();
  $('endBtn').disabled = !(state === 'ringing' || state === 'connected');
  document.querySelectorAll('.key').forEach(k => k.disabled = state !== 'idle');
}
function startTimer() {
  stopTimer(); const t0 = Date.now();
  timerInt = setInterval(() => {
    const s = Math.floor((Date.now() - t0) / 1000);
    $('timer').textContent = `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
  }, 1000);
}
function stopTimer() { if (timerInt) clearInterval(timerInt); timerInt = null; $('timer').innerHTML = '&nbsp;'; }
function showPad() { $('padView').classList.remove('hidden'); $('dirView').classList.add('hidden'); $('tabBtn').classList.remove('active'); }

function renderDir(filter = '') {
  const f = filter.toLowerCase(), list = $('dirList'); list.innerHTML = '';
  const rows = directory.filter(d => d.label.toLowerCase().includes(f) || d.number.includes(f));
  if (!rows.length) { const e = document.createElement('div'); e.className = 'empty'; e.textContent = T.empty; list.appendChild(e); return; }
  rows.forEach(d => {
    const el = document.createElement('div'); el.className = 'row' + (d.listed ? '' : ' unlisted');
    el.innerHTML = `<div class="badge">&#9742;</div><div class="name"><span></span><small></small></div><div class="pill"></div>`;
    el.querySelector('.name span').textContent = d.label; el.querySelector('.pill').textContent = d.number;
    if (!d.listed) el.querySelector('.name small').textContent = T.hidden;
    el.onclick = () => { if (state !== 'idle') return; digits = d.number; showPad(); render(); };
    if (isAdmin) {
      const b = document.createElement('button'); b.className = 'circle sm';
      b.innerHTML = d.listed ? '&#10005;' : '&#10003;'; b.title = d.listed ? T.hide : T.show;
      b.onclick = async ev => {
        ev.stopPropagation(); b.disabled = true;
        const res = await post('setListed', { id: d.id, listed: !d.listed });
        if (res && res.ok) { directory = res.entries; renderDir($('search').value); } else b.disabled = false;
      };
      el.appendChild(b);
    }
    list.appendChild(el);
  });
}

async function call() {
  if (state !== 'idle' || digits.length < 2) return;
  state = 'dialling'; setStatus(T.dialling, 'warn'); render();
  const res = await post('dial', { number: digits, deposit: pay ? credit / 100 : 0 });
  if (res && res.ok) {
    state = 'ringing'; setStatus(fmt(T.ringing, res.info.label), 'warn'); startRingback();
    if (pay) $('coins').classList.add('hidden');
  } else { state = 'idle'; setStatus(T.ready); }
  render();
}
function hangUp() { if (state !== 'ringing' && state !== 'connected') return; stopRingback(); stopTimer(); state = 'ended'; setStatus(T.ended, 'bad'); render(); post('hangUp'); }

function open(data) {
  applyText(data.ui); $('app').classList.remove('hidden'); showPad(); stopTimer(); stopRingback();
  setupPay(data);
  $('ownLine').textContent = data.phone ? `${data.phone.label} · ${data.phone.number}` : '—';
  if (data.mode === 'connected') {
    state = 'connected'; digits = data.info ? data.info.number : '';
    setStatus(fmt(T.connected, data.info && data.info.label), 'ok'); startTimer();
  } else { state = 'idle'; digits = ''; setStatus(T.ready); }
  render();
}
function close() { $('app').classList.add('hidden'); stopRingback(); stopTimer(); state = 'idle'; digits = ''; }

/* ---------------- events ---------------- */
document.querySelectorAll('.key').forEach(k => k.addEventListener('click', () => {
  if (state !== 'idle') return;
  const v = k.dataset.k;
  if (v === 'clear') digits = ''; else if (v === 'del') digits = digits.slice(0, -1);
  else if (digits.length < 16) { digits += v; dialClick(v); }
  render();
}));
$('callBtn').onclick = call;
$('endBtn').onclick = hangUp;
$('closeBtn').onclick = () => post('close');
$('tabBtn').onclick = async () => {
  if (!$('dirView').classList.contains('hidden')) return showPad();
  $('padView').classList.add('hidden'); $('dirView').classList.remove('hidden'); $('tabBtn').classList.add('active');
  const res = (await post('getDirectory')) || {};
  directory = res.entries || []; isAdmin = !!res.admin; $('search').value = ''; renderDir();
};
$('search').oninput = e => renderDir(e.target.value);

document.addEventListener('keydown', e => {
  if ($('app').classList.contains('hidden')) return;
  if (e.key === 'Escape') { stopRingback(); stopTimer(); return post('close'); }
  if (document.activeElement === $('search')) return;
  if (state === 'idle') {
    if (/^[0-9]$/.test(e.key) && digits.length < 16) { digits += e.key; dialClick(e.key); render(); }
    else if (e.key === 'Backspace') { digits = digits.slice(0, -1); render(); }
    else if (e.key === 'Enter') call();
  }
});

window.addEventListener('message', ({ data }) => {
  switch (data.action) {
    case 'open': open(data); break;
    case 'close': close(); break;
    case 'connected':
      stopRingback(); state = 'connected'; setStatus(fmt(T.connected, data.info && data.info.label), 'ok'); startTimer(); render(); break;
    case 'ended':
      stopRingback(); stopTimer(); state = 'ended'; setStatus(data.reason || T.ended, 'bad'); render(); break;
    case 'credit':
      if (pay) showCredit(data.left, fmt(T.mins_left, (data.cost > 0 ? Math.floor(data.left / data.cost) : 0) + 1));
      break;
    case 'formShow': openForm(data); break;
    case 'placeShow': {
      const u = data.ui || {};
      const ke = document.querySelector('[data-pk="enter"]'), kb = document.querySelector('[data-pk="back"]');
      if (u.key_enter) ke.textContent = u.key_enter; if (u.key_back) kb.textContent = u.key_back;
      [['plTitle','title'],['plRotate','rotate'],['plHeight','height'],['plMove','move'],['plFwdL','distance'],['plPlace','place'],['plCancel','cancel'],['plHeadingL','heading'],['plOffsetL','offset']]
        .forEach(([id, k]) => { if (u[k]) $(id).textContent = u[k]; });
      document.querySelectorAll('.kc').forEach(k => k.classList.remove('on'));
      $('placer').classList.remove('hidden'); break;
    }
    case 'placeUpdate':
      document.querySelectorAll('.kc').forEach(k => k.classList.toggle('on', !!(data.keys && data.keys[k.dataset.pk])));
      $('plHeading').textContent = `${data.heading}°`;
      $('plOffset').textContent = `${data.offset > 0 ? '+' : ''}${data.offset}`;
      $('plFwd').textContent = `${data.forward > 0 ? '+' : ''}${data.forward}`;
      document.querySelector('[data-pk="enter"]').classList.toggle('off', !data.valid);
      break;
    case 'placeHide': $('placer').classList.add('hidden'); break;
    case 'bell':
      if (data.volume > 0) bells[data.id] = { volume: data.volume, pan: data.pan || 0, muffled: !!data.muffled };
      else delete bells[data.id];
      updateBells(); break;
  }
});

/* ---------------- placement details form ---------------- */
let formUI = {}, formModel = null, formListed = true;
let formMode = 'admin';
function openForm(data) {
  formUI = data.ui || {}; formMode = data.mode || 'admin';
  const show = (id, v) => $(id).classList.toggle('hidden', !v);
  show('fNumberL', formMode === 'admin'); show('fNumber', formMode === 'admin');
  show('fJobL', formMode === 'admin'); show('fJob', formMode === 'admin');
  show('fModelL', formMode !== 'settings'); show('fModels', formMode !== 'settings');
  [['fTitle','title'],['fLabelL','label'],['fModelL','model'],['fNumberL','number'],['fListedL','listed'],['fJobL','job'],['fCancel','cancel'],['fConfirm','confirm']]
    .forEach(([id, k]) => { if (formUI[k]) $(id).textContent = formUI[k]; });
  if (formUI.job_hint) $('fJob').placeholder = formUI.job_hint;
  const box = $('fModels'); box.innerHTML = '';
  (data.models || []).forEach((m, i) => {
    const el = document.createElement('div'); el.className = 'row model';
    el.innerHTML = '<div class="badge">&#9742;</div><div class="name"></div>';
    el.querySelector('.name').textContent = m.label;
    el.onclick = () => { formModel = m.value; box.querySelectorAll('.model').forEach(x => x.classList.toggle('sel', x === el)); };
    box.appendChild(el); if (i === 0) el.onclick();
  });
  const pre = data.preset || {};
  $('fLabel').value = pre.label || ''; $('fNumber').value = ''; $('fJob').value = ''; setListed(pre.listed !== false); $('fError').innerHTML = '&nbsp;';
  if (formMode === 'settings') { $('fConfirm').textContent = formUI.save; if (pre.number) $('fTitle').textContent = `${formUI.title} · ${pre.number}`; }
  $('form').classList.remove('hidden'); setTimeout(() => $('fLabel').focus(), 50);
}
function setListed(v) { formListed = v; $('fListed').classList.toggle('on', v); }
function closeForm(payload) { $('form').classList.add('hidden'); post('placeForm', payload); }
function submitForm() {
  const label = $('fLabel').value.trim(), number = $('fNumber').value.trim();
  if (!label) { $('fError').textContent = formUI.required; return $('fLabel').focus(); }
  if (formMode === 'admin' && number && !/^\d{2,16}$/.test(number)) { $('fError').textContent = formUI.invalid; return $('fNumber').focus(); }
  closeForm({ label, model: formModel, number, listed: formListed, job: $('fJob').value.trim() });
}
$('fListed').onclick = () => setListed(!formListed);
$('fNumber').oninput = e => { e.target.value = e.target.value.replace(/\D/g, ''); };
$('fConfirm').onclick = submitForm;
$('fCancel').onclick = () => closeForm({ cancel: true });
document.addEventListener('keydown', e => {
  if ($('form').classList.contains('hidden')) return;
  if (e.key === 'Escape') closeForm({ cancel: true });
  else if (e.key === 'Enter') submitForm();
});

/* ---------------- payphone ---------------- */
const money = c => `$${(c / 100).toFixed(2)}`;
function showCredit(c, extra) { $('payCredit').textContent = `${T.credit} ${money(c)}${extra ? ' · ' + extra : ''}`; }
function setupPay(data) {
  // the person answering never pays, so only the dial screen shows the coin slot
  pay = data.mode === 'connected' ? null : (data.pay || null); credit = 0;
  $('payRow').classList.toggle('hidden', !pay);
  if (!pay) return;
  $('payRate').textContent = `${money(Math.round(pay.cost * 100))} ${T.per_min}`;
  const box = $('coins'); box.innerHTML = ''; box.classList.remove('hidden');
  (pay.coins || []).forEach(v => {
    const b = document.createElement('button'); b.className = 'coin';
    b.textContent = v < 1 ? `${Math.round(v * 100)}¢` : `$${v}`;
    b.onclick = () => {
      if (state !== 'idle') return;
      const add = Math.round(v * 100);
      if (credit + add > Math.round(pay.max * 100)) return;
      if (credit + add > cashCents()) return payMsg(T.no_cash); // can't insert more than you carry
      credit += add; coinDrop(); showCredit(credit); render();
    };
    box.appendChild(b);
  });
  const r = document.createElement('button'); r.className = 'coin ret'; r.textContent = T.coin_return;
  r.onclick = () => { if (state !== 'idle' || !credit) return; credit = 0; showCredit(0); render(); };
  box.appendChild(r);
  showCredit(0);
  refreshCoins();
}
const cashCents = () => Math.floor((Number(pay && pay.cash) || 0) * 100 + 0.5);
// grey out coins that would take you past your cash or the max deposit
function refreshCoins() {
  if (!pay) return;
  const limit = Math.min(Math.round(pay.max * 100), cashCents());
  document.querySelectorAll('#coins .coin:not(.ret)').forEach((b, i) => {
    const add = Math.round((pay.coins[i] || 0) * 100);
    b.disabled = state !== 'idle' || credit + add > limit;
  });
  if (state === 'idle' && cashCents() < Math.round(pay.cost * 100)) payMsg(T.no_cash);
}
let payMsgT = null;
function payMsg(text) {
  if (!text) return;
  $('payRate').textContent = text; $('payRate').classList.add('warn');
  clearTimeout(payMsgT);
  payMsgT = setTimeout(() => { $('payRate').classList.remove('warn'); if (pay) $('payRate').textContent = `${money(Math.round(pay.cost * 100))} ${T.per_min}`; }, 2500);
}
// small metallic clink when a coin goes in
function coinDrop() {
  const a = ac(), t = a.currentTime;
  [2600, 3900].forEach((f, i) => {
    const o = a.createOscillator(), g = a.createGain(); o.frequency.value = f;
    g.gain.setValueAtTime(0.08, t + i * 0.07); g.gain.exponentialRampToValueAtTime(0.0001, t + i * 0.07 + 0.25);
    o.connect(g); g.connect(a.destination); o.start(t + i * 0.07); o.stop(t + i * 0.07 + 0.3);
  });
}

/* ---------------- admin panel ---------------- */
let A = { phones: [], calls: 0, models: [] }, AT = {}, aSel = null, aModel = null, aListedV = true;
function aSetText() {
  [['aTitle','title'],['aLabelL','label'],['aNumberL','number'],['aJobL','job'],['aModelL','model'],['aListedL','listed'],
   ['aSave','save'],['aDelete','delete'],['aTeleport','teleport'],['aWaypoint','waypoint'],['aEndCall','endcall'],
   ['aEmpty','select'],['aConfirmNo','cancel'],['aConfirmYes','delete']]
    .forEach(([id, k]) => { if (AT[k]) $(id).textContent = AT[k]; });
  if (AT.search) $('aSearch').placeholder = AT.search;
  if (AT.add) $('aAdd').title = AT.add;
  $('aJob').placeholder = AT.anyone; $('aClose').title = AT.close;
}
function aLoad(data) {
  if (!data) return;
  A = data;
  $('aStats').textContent = `${A.phones.length} ${AT.phones} · ${A.calls} ${AT.calls}`;
  aRenderList();
  if (aSel) { const p = A.phones.find(x => x.id === aSel); p ? aEdit(p, true) : aClear(); }
}
const statusText = s => s === 'ringing' ? AT.ringing : s === 'call' ? AT.incall : s === 'stored' ? AT.stored : AT.idle;
function aRenderList() {
  const f = $('aSearch').value.toLowerCase(), list = $('aList'); list.innerHTML = '';
  const rows = A.phones.filter(p => p.label.toLowerCase().includes(f) || p.number.includes(f) || p.job.includes(f));
  if (!rows.length) { const e = document.createElement('div'); e.className = 'empty'; e.textContent = AT.empty; list.appendChild(e); return; }
  rows.forEach(p => {
    const el = document.createElement('div');
    el.className = 'row' + (p.id === aSel ? ' sel' : '') + (p.listed ? '' : ' unlisted');
    el.innerHTML = '<div class="badge">&#9742;</div><div class="name"><span></span><small class="tags"></small></div><div class="pill"></div><div class="dot"></div>';
    el.querySelector('.name span').textContent = p.label;
    const tags = [];
    if (p.job) tags.push(p.job); else if (p.payphone) tags.push(AT.payphone);
    if (p.owned) tags.push(AT.owned);
    if (!p.listed) tags.push(AT.hidden);
    el.querySelector('.tags').textContent = tags.join(' · ');
    el.querySelector('.pill').textContent = p.number;
    el.querySelector('.dot').className = 'dot ' + p.status;
    el.onclick = () => aEdit(p);
    list.appendChild(el);
  });
}
function aClear() { aSel = null; $('aEditor').classList.add('hidden'); $('aEmpty').classList.remove('hidden'); aRenderList(); }
function aSetListed(v) { aListedV = v; $('aListed').classList.toggle('on', v); }
function aEdit(p, keepFields) {
  aSel = p.id; $('aEmpty').classList.add('hidden'); $('aEditor').classList.remove('hidden');
  $('aHeadLabel').textContent = `#${p.id} · ${p.label}`;
  const st = $('aStatus'); st.textContent = statusText(p.status); st.className = 'a-status ' + p.status;
  const stored = p.status === 'stored'; // picked up: not in the world, can only be deleted
  $('aEndCall').disabled = p.status === 'idle' || stored;
  ['aTeleport','aWaypoint','aSave','aLabel','aNumber','aJob'].forEach(id => $(id).disabled = stored);
  $('aModels').classList.toggle('locked', stored); $('aListed').classList.toggle('locked', stored);
  $('aCoords').textContent = `${p.x.toFixed(2)}, ${p.y.toFixed(2)}, ${p.z.toFixed(2)}`;
  if (!keepFields) {
    $('aLabel').value = p.label; $('aNumber').value = p.number; $('aJob').value = p.job; aSetListed(p.listed);
    aModel = p.model; $('aError').innerHTML = '&nbsp;';
  }
  const box = $('aModels'); box.innerHTML = '';
  A.models.forEach(m => {
    const b = document.createElement('button'); b.className = 'coin a-model' + (m.value === aModel ? ' sel' : '');
    b.textContent = m.label; b.onclick = () => { aModel = m.value; aEdit(A.phones.find(x => x.id === aSel), true); };
    box.appendChild(b);
  });
  aRenderList();
}
async function aSave() {
  const label = $('aLabel').value.trim(), number = $('aNumber').value.trim();
  if (!label) return ($('aError').textContent = AT.required);
  if (!/^\d{2,16}$/.test(number)) return ($('aError').textContent = AT.invalid);
  $('aError').innerHTML = '&nbsp;'; $('aSave').disabled = true;
  const res = await post('adminSave', { id: aSel, label, number, job: $('aJob').value.trim(), model: aModel, listed: aListedV });
  $('aSave').disabled = false;
  if (res) { A = res; aLoad(res); const p = A.phones.find(x => x.id === aSel); if (p) aEdit(p); }
}
$('aSearch').oninput = aRenderList;
$('aNumber').oninput = e => { e.target.value = e.target.value.replace(/\D/g, ''); };
$('aListed').onclick = () => aSetListed(!aListedV);
$('aSave').onclick = aSave;
$('aClose').onclick = () => post('adminClose');
$('aAdd').onclick = () => post('adminAdd');
$('aTeleport').onclick = () => aSel && post('adminTeleport', { id: aSel });
$('aWaypoint').onclick = () => aSel && post('adminWaypoint', { id: aSel });
$('aEndCall').onclick = async () => { if (aSel) aLoad(await post('adminEndCall', { id: aSel })); };
$('aDelete').onclick = () => {
  const p = A.phones.find(x => x.id === aSel); if (!p) return;
  $('aConfirmText').textContent = `${AT.confirm} ${p.label} (${p.number})?`;
  $('aConfirm').classList.remove('hidden');
};
$('aConfirmNo').onclick = () => $('aConfirm').classList.add('hidden');
$('aConfirmYes').onclick = async () => {
  $('aConfirm').classList.add('hidden');
  const res = await post('adminDelete', { id: aSel });
  if (res) { aSel = null; aLoad(res); aClear(); }
};
let aRefresh = null;
window.addEventListener('message', ({ data }) => {
  if (data.action === 'adminOpen') {
    AT = data.ui || {}; aSetText(); aSel = null; $('aSearch').value = '';
    $('aEditor').classList.add('hidden'); $('aEmpty').classList.remove('hidden'); $('aConfirm').classList.add('hidden');
    aLoad(data.data); $('admin').classList.remove('hidden');
    clearInterval(aRefresh); aRefresh = setInterval(async () => aLoad(await post('adminRefresh')), 5000); // live call status
  } else if (data.action === 'adminClose') {
    $('admin').classList.add('hidden'); clearInterval(aRefresh); aRefresh = null;
  }
});
document.addEventListener('keydown', e => {
  if ($('admin').classList.contains('hidden') || e.key !== 'Escape') return;
  if (!$('aConfirm').classList.contains('hidden')) return $('aConfirm').classList.add('hidden');
  post('adminClose');
});
