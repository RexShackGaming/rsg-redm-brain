const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-weather';
const $ = (id) => document.getElementById(id);
const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const ICONS = { sunny:'☀', highpressure:'☀', clouds:'☁', overcast:'☁', overcastdark:'☁', fog:'≋', misty:'≋', drizzle:'☂', rain:'☂', shower:'☂', thunder:'⚡', thunderstorm:'⚡', hurricane:'🌀', sandstorm:'≋', hail:'❄', sleet:'❄', snow:'❄', snowlight:'❄', blizzard:'❄', groundblizzard:'❄', whiteout:'❄' };

let weatherTypes = [];
let state = {};
let patterns = { active: 'default', patterns: {}, default: {} };
let editor = { name: '', original: null, blocks: {} }; // blocks: { from: [{to, chance}] }
let currentTab = 'weather';
let LOCALE = {};
// L('key', 'fallback %s', arg) -> translated string with %s / %d placeholders filled in order
const L = (key, fallback, ...args) => { let i = 0; return String(LOCALE[key] || fallback || key).replace(/%[sd]/g, () => (args[i++] ?? '')); };
const WL = (w) => L('weather_' + w, w);
const DAYS_L = () => [0,1,2,3,4,5,6].map(i => L('ui_' + ['sun','mon','tue','wed','thu','fri','sat'][i], DAYS[i]));
function applyLocale(dict) {
  if (!dict) return;
  LOCALE = dict;
  document.querySelectorAll('[data-l]').forEach(el => { if (LOCALE[el.dataset.l]) el.textContent = LOCALE[el.dataset.l]; });
  document.querySelectorAll('[data-lp]').forEach(el => { if (LOCALE[el.dataset.lp]) el.placeholder = LOCALE[el.dataset.lp]; });
}

const post = (cb, data = {}) => fetch(`https://${RES}/${cb}`, {
  method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data)
}).then(r => r.json()).catch(() => ({}));

function toast(msg, type = 'info', label) {
  const el = document.createElement('div');
  el.className = `toast ${type}`;
  el.innerHTML = `<div class="lbl"></div><div class="msg"></div>`;
  el.querySelector('.lbl').textContent = label || (type === 'error' ? L('ui_toast_error', 'Error') : type === 'success' ? L('ui_toast_done', 'Done') : L('ui_weather', 'Weather'));
  el.querySelector('.msg').textContent = msg;
  $('toasts').appendChild(el);
  setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 260); }, 3200);
}

function confirmBox(title, text) {
  return new Promise(res => {
    $('modalTitle').textContent = title; $('modalText').textContent = text;
    $('modal').classList.remove('hidden');
    const done = (v) => { $('modal').classList.add('hidden'); $('modalYes').onclick = $('modalNo').onclick = null; res(v); };
    $('modalYes').onclick = () => done(true); $('modalNo').onclick = () => done(false);
  });
}

const esc = (s) => String(s).replace(/[&<>"']/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[c]));
const weatherSelect = (sel, value) => { sel.innerHTML = weatherTypes.map(w => `<option value="${w}" ${w === value ? 'selected' : ''}>${esc(WL(w))}</option>`).join(''); };

/* ---------- tabs ---------- */
function showTab(tab) {
  currentTab = tab;
  document.querySelectorAll('.tab').forEach(b => b.classList.toggle('active', b.dataset.tab === tab || (tab === 'editor' && b.dataset.tab === 'patterns')));
  document.querySelectorAll('.tab-page').forEach(p => p.classList.toggle('hidden', p.id !== `tab-${tab}`));
  if (tab === 'patterns') renderPatternList();
}
document.querySelectorAll('.tab').forEach(b => b.addEventListener('click', () => showTab(b.dataset.tab)));

/* ---------- live state ---------- */
function renderState(fill) {
  const t = state.time || 0;
  const d = Math.floor(t / 86400), h = Math.floor(t / 3600) % 24, m = Math.floor(t / 60) % 60;
  const fz = ' (' + L('ui_frozen', 'frozen') + ')';
  $('curWeather').textContent = `${WL(state.weather)}${state.weatherFrozen ? fz : ''}${state.permanentSnow ? ' · ' + L('ui_snow', 'snow') : ''}`;
  $('curPattern').textContent = patterns.active;
  $('curTime').textContent = `${DAYS_L()[d % 7]} ${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}${state.timeFrozen ? fz : ''}`;
  $('curScale').textContent = state.timescale == 0 ? L('ui_real', 'real') : `x${state.timescale}`;
  $('curWind').textContent = `${Math.round(state.windDirection)}° · ${L('ui_speed', 'speed')} ${state.windSpeed}${state.windFrozen ? fz : ''}`;
  $('windArrow').style.transform = `rotate(${state.windDirection}deg)`;
  const se = state.season;
  if (se) {
    const ev = se.events.find(e => e.name === se.current);
    $('curSeason').textContent = ev ? L('ui_season_active', '%s active', ev.label) : L('ui_season_none', 'none active');
    $('seasonIcon').textContent = ev ? (ev.icon || '✦') : '✦';
    $('seasonMode').textContent = se.mode;
    $('seasonMode').classList.toggle('on', !!ev);
    $('seasonHint').textContent = se.events.map(e => `${e.label}: ${e.range}`).join(' · ') + ' ' + L('ui_ddmm', '(dd/mm)');
  }
  if (fill) {
    if (se) $('sMode').innerHTML = [['auto', L('ui_mode_auto', 'Auto (by real date)')], ['off', L('ui_mode_off', 'Off')], ...se.events.map(e => [e.name, L('ui_mode_force', 'Force %s', e.label)])]
      .map(([v, l]) => `<option value="${v}" ${v === se.mode ? 'selected' : ''}>${esc(l)}</option>`).join('');
    weatherSelect($('wType'), state.weather);
    $('wFreeze').checked = !!state.weatherFrozen; $('wSnow').checked = !!state.permanentSnow;
    $('tDay').querySelectorAll('option').forEach((o, i) => { o.textContent = DAYS_L()[i]; });
    $('tDay').value = d % 7; $('tHour').value = h; $('tMin').value = m; $('tFreeze').checked = !!state.timeFrozen;
    $('tScale').value = state.timescale; $('tSync').value = state.syncDelay;
    $('wdDir').value = Math.round(state.windDirection); $('dirVal').textContent = `${Math.round(state.windDirection)}°`;
    $('wdSpeed').value = state.windSpeed; $('wdFreeze').checked = !!state.windFrozen;
  }
}

async function act(name, data, okMsg) {
  const r = await post('action', { name, data });
  r.ok ? toast(okMsg, 'success') : toast(L('ui_action_failed', 'Action failed'), 'error');
}

$('wApply').onclick = () => act('weather', { weather: $('wType').value, transition: Math.max(0.1, +$('wTrans').value || 10), freeze: $('wFreeze').checked, permanentSnow: $('wSnow').checked }, L('ui_weather_set', 'Weather set to %s', WL($('wType').value)));
$('tApply').onclick = () => act('time', { day: +$('tDay').value, hour: +$('tHour').value, minute: +$('tMin').value, second: 0, transition: +$('tTrans').value || 0, freeze: $('tFreeze').checked }, L('ui_time_updated', 'Time updated'));
$('scaleApply').onclick = () => act('timescale', { timescale: +$('tScale').value }, L('ui_timescale_updated', 'Timescale updated'));
$('syncApply').onclick = () => act('syncdelay', { delay: +$('tSync').value }, L('ui_sync_updated', 'Sync delay updated'));
$('sApply').onclick = () => act('season', { mode: $('sMode').value }, L('ui_season_updated', 'Season mode updated'));
$('wdDir').oninput = () => { $('dirVal').textContent = `${$('wdDir').value}°`; };
$('wdApply').onclick = () => act('wind', { direction: +$('wdDir').value, speed: +$('wdSpeed').value || 0, freeze: $('wdFreeze').checked }, L('ui_wind_updated', 'Wind updated'));
$('resetAll').onclick = async () => {
  if (await confirmBox(L('ui_reset_title', 'Reset Everything'), L('ui_reset_text', 'Weather, time, wind and pattern go back to config values.'))) {
    await act('reset', {}, L('ui_reset_done', 'Reset to config'));
    patterns.active = 'default'; renderState(true);
  }
};

/* ---------- pattern list ---------- */
function summary(p) {
  const keys = Object.keys(p || {});
  return L('ui_pattern_summary', '%s weather types', keys.length) + ` · ${keys.slice(0, 4).map(WL).join(', ')}${keys.length > 4 ? '…' : ''}`;
}

function renderPatternList() {
  const list = $('patternList');
  const entries = [['default', patterns.default, true], ...Object.keys(patterns.patterns).sort().map(n => [n, patterns.patterns[n], false])];
  list.innerHTML = entries.map(([name, p, isDef]) => `
    <div class="row">
      <div class="badge-ico">${isDef ? '⚙' : '✎'}</div>
      <div class="grow"><div class="t">${esc(name)}</div><div class="d">${isDef ? esc(L('ui_from_config', 'From config')) + ' · ' : ''}${esc(summary(p))}</div></div>
      ${patterns.active === name ? `<span class="pill on">${esc(L('ui_active', 'Active'))}</span>` : ''}
      <div class="row-btns">
        ${patterns.active !== name ? `<button class="wood-btn mini" data-apply="${esc(name)}">${esc(L('ui_apply', 'Apply'))}</button>` : ''}
        <button class="wood-btn mini" data-edit="${esc(name)}">${esc(isDef ? L('ui_copy', 'Copy') : L('ui_edit', 'Edit'))}</button>
        ${isDef ? '' : `<button class="wood-btn mini danger" data-del="${esc(name)}">✕</button>`}
      </div>
    </div>`).join('');

  list.querySelectorAll('[data-apply]').forEach(b => b.onclick = async () => {
    const r = await post('applyPattern', { name: b.dataset.apply });
    if (r.ok) { patterns = r.patterns; renderPatternList(); renderState(); toast(L('ui_pattern_active', 'Pattern "%s" is now active', b.dataset.apply), 'success'); }
    else toast(L('ui_pattern_apply_failed', 'Could not apply pattern'), 'error');
  });
  list.querySelectorAll('[data-edit]').forEach(b => b.onclick = () => {
    const n = b.dataset.edit;
    openEditor(n === 'default' ? '' : n, n === 'default' ? patterns.default : patterns.patterns[n]);
  });
  list.querySelectorAll('[data-del]').forEach(b => b.onclick = async () => {
    if (!(await confirmBox(L('ui_delete_title', 'Delete Pattern'), L('ui_delete_text', 'Delete "%s"? If active, weather falls back to the default pattern.', b.dataset.del)))) return;
    const r = await post('deletePattern', { name: b.dataset.del });
    if (r.ok) { patterns = r.patterns; renderPatternList(); renderState(); toast(L('ui_pattern_deleted', 'Pattern deleted'), 'success'); }
    else toast(L('ui_pattern_delete_failed', 'Could not delete pattern'), 'error');
  });
}

/* ---------- pattern editor ---------- */
function openEditor(name, pattern) {
  editor = { name, original: name || null, blocks: {} };
  Object.entries(pattern || {}).forEach(([from, choices]) => {
    editor.blocks[from] = Object.entries(choices).map(([to, chance]) => ({ to, chance }));
  });
  $('pName').value = name;
  renderEditor();
  showTab('editor');
}
$('newPattern').onclick = () => openEditor('', { sunny: { sunny: 100 } });
$('pCancel').onclick = () => showTab('patterns');

function renderEditor() {
  const used = new Set();
  Object.values(editor.blocks).forEach(rows => rows.forEach(r => r.chance > 0 && used.add(r.to)));
  const blocks = $('blocks');
  blocks.innerHTML = Object.keys(editor.blocks).map(from => {
    const rows = editor.blocks[from];
    const sum = rows.reduce((a, r) => a + (+r.chance || 0), 0);
    const cls = sum === 100 ? 'good' : sum > 100 ? 'bad' : 'warn';
    return `<div class="block" data-from="${from}">
      <div class="block-head">
        <div class="badge-ico">${ICONS[from] || '☁'}</div>
        <div class="t">${esc(WL(from))} <span class="pill">${esc(L('ui_then', 'then…'))}</span></div>
        <div class="sum ${cls === 'good' ? 'ok' : cls}">${sum}%</div>
        <button class="circle-btn x-btn" data-rmblock="${from}" title="Remove">✕</button>
      </div>
      <div class="track"><div class="fill stat-${cls}" style="width:${Math.min(sum, 100)}%"></div></div>
      ${rows.map((r, i) => `<div class="next-row">
          <select data-to="${i}">${weatherTypes.map(w => `<option value="${w}" ${w === r.to ? 'selected' : ''}>${esc(WL(w))}</option>`).join('')}</select>
          <input type="number" min="0" max="100" value="${r.chance}" data-ch="${i}">
          <button class="circle-btn x-btn" data-rmrow="${i}">✕</button>
        </div>`).join('')}
      <div class="actions" style="margin-top:6px">
        <button class="wood-btn muted mini" data-addrow>${esc(L('ui_next_weather', '+ Next weather'))}</button>
        <button class="wood-btn muted mini" data-even>${esc(L('ui_split_evenly', 'Split evenly'))}</button>
      </div>
    </div>`;
  }).join('');

  const missing = [...used].filter(w => !editor.blocks[w]);
  if (missing.length) blocks.insertAdjacentHTML('beforeend', `<div class="missing">${esc(L('ui_needs_block', 'Needs a block for: %s', missing.map(WL).join(', ')))}</div>`);

  // "add weather" dropdown shows missing ones first
  const avail = weatherTypes.filter(w => !editor.blocks[w]);
  avail.sort((a, b) => missing.includes(b) - missing.includes(a));
  $('addFrom').innerHTML = avail.map(w => `<option value="${w}">${esc(WL(w))}${missing.includes(w) ? '  (' + esc(L('ui_needed', 'needed')) + ')' : ''}</option>`).join('');
  $('addBlock').disabled = !avail.length;

  blocks.querySelectorAll('.block').forEach(el => {
    const from = el.dataset.from, rows = editor.blocks[from];
    el.querySelectorAll('[data-to]').forEach(s => s.onchange = () => { rows[+s.dataset.to].to = s.value; renderEditor(); });
    el.querySelectorAll('[data-ch]').forEach(inp => inp.onchange = () => { rows[+inp.dataset.ch].chance = Math.max(0, Math.min(100, Math.floor(+inp.value || 0))); renderEditor(); });
    el.querySelectorAll('[data-rmrow]').forEach(b => b.onclick = () => { rows.splice(+b.dataset.rmrow, 1); renderEditor(); });
    el.querySelector('[data-rmblock]').onclick = () => { delete editor.blocks[from]; renderEditor(); };
    el.querySelector('[data-addrow]').onclick = () => {
      const taken = rows.map(r => r.to);
      rows.push({ to: weatherTypes.find(w => !taken.includes(w)) || from, chance: Math.max(0, 100 - rows.reduce((a, r) => a + r.chance, 0)) });
      renderEditor();
    };
    el.querySelector('[data-even]').onclick = () => {
      if (!rows.length) return;
      const base = Math.floor(100 / rows.length);
      rows.forEach((r, i) => r.chance = base + (i < 100 - base * rows.length ? 1 : 0));
      renderEditor();
    };
  });
}

$('addBlock').onclick = () => {
  const w = $('addFrom').value; if (!w) return;
  editor.blocks[w] = [{ to: w, chance: 100 }];
  renderEditor();
};

function buildPattern() {
  const out = {};
  for (const [from, rows] of Object.entries(editor.blocks)) {
    out[from] = {};
    rows.forEach(r => { if (r.chance > 0) out[from][r.to] = (out[from][r.to] || 0) + r.chance; });
  }
  return out;
}

async function savePattern(apply) {
  const name = $('pName').value.trim();
  if (!name) return toast(L('ui_name_required', 'Give the pattern a name'), 'error');
  if (name.toLowerCase() === 'default') return toast(L('ui_name_reserved', '"default" is reserved'), 'error');
  if (patterns.patterns[name] && name !== editor.original &&
      !(await confirmBox(L('ui_overwrite_title', 'Overwrite'), L('ui_overwrite_text', 'A pattern called "%s" exists. Overwrite it?', name)))) return;
  const r = await post('savePattern', { name, pattern: buildPattern(), apply });
  if (!r.ok) return toast(r.error || L('ui_save_failed', 'Save failed'), 'error');
  patterns = r.patterns;
  editor.original = name;
  renderState();
  toast(apply ? L('ui_saved_applied', '"%s" saved and applied', name) : L('ui_saved', '"%s" saved', name), 'success');
  showTab('patterns');
}
$('pSave').onclick = () => savePattern(false);
$('pSaveApply').onclick = () => savePattern(true);

/* ---------- open / close ---------- */
function closeAdmin() { $('app').classList.add('hidden'); $('modal').classList.add('hidden'); post('close'); }
$('closeBtn').onclick = closeAdmin;
// ESC closes an open confirm dialog first, then the panel
document.addEventListener('keydown', e => {
  if (e.key !== 'Escape' || $('app').classList.contains('hidden')) return;
  if (!$('modal').classList.contains('hidden')) { $('modalNo').click(); return; }
  closeAdmin();
});

/* ---------- forecast overlay ---------- */
function renderForecast(d) {
  const now = d.entries[0];
  $('fcIcon').textContent = ICONS[now.weather] || '☁';
  $('fcWeather').textContent = now.label || WL(now.weather);
  $('fcSub').textContent = d.season ? `${d.season.icon || '✦'} ${d.season.label} ${d.season.icon || '✦'}` : L('ui_weather_bulletin', 'Weather Bulletin');
  $('fcPanel').classList.toggle('halloween', d.season && d.season.name === 'halloween');
  $('fcPanel').classList.toggle('christmas', d.season && d.season.name === 'christmas');
  $('fcTimeNow').textContent = `${now.day} ${now.time}${d.synced ? '' : ' · ' + L('ui_sync_off', 'sync off')}`;
  $('fcTemp').textContent = d.temperature;
  $('fcWind').textContent = d.wind;
  $('fcArrow').style.transform = `rotate(${d.windDeg}deg)`;
  $('fcAlt').textContent = `${d.altitude} m`;
  let lastDay = now.day;
  $('fcList').innerHTML = d.entries.slice(1).map(e => {
    const nd = e.day !== lastDay; lastDay = e.day;
    return `<div class="fc-row${nd ? ' newday' : ''}"><span class="day">${esc(e.day)}</span><span class="tm">${esc(e.time)}</span><span class="ic">${ICONS[e.weather] || '☁'}</span><span class="w">${esc(e.label || WL(e.weather))}</span><span class="wd">${esc(e.wind)}</span></div>`;
  }).join('');
  const el = $('forecast'); el.classList.remove('closing'); el.classList.remove('hidden');
}

window.addEventListener('message', ({ data }) => {
  if (data.action === 'locale') { applyLocale(data.locale); return; }
  if (data.action === 'forecast') { renderForecast(data.data); return; }
  if (data.action === 'forecastShow') { if ($('fcList').children.length) $('forecast').classList.remove('hidden'); return; }
  if (data.action === 'forecastClose') { const el = $('forecast'); el.classList.add('closing'); setTimeout(() => { el.classList.add('hidden'); el.classList.remove('closing'); }, 250); return; }
  if (data.action === 'open') {
    applyLocale(data.locale);
    weatherTypes = data.weatherTypes || [];
    state = data.state || {};
    if (data.patterns) patterns = data.patterns;
    renderState(true);
    showTab(currentTab === 'editor' ? 'patterns' : currentTab);
    $('app').classList.remove('hidden');
  } else if (data.action === 'state') {
    state = data.state; renderState(false);
  } else if (data.action === 'close') {
    $('app').classList.add('hidden');
  }
});
