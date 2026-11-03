const progressFill = document.getElementById('progressFill');
const percentText = document.getElementById('percentText');
const statusText = document.getElementById('statusText');
const tipText = document.getElementById('tipText');
const clockEl = document.getElementById('clock');
const brandTitle = document.getElementById('brandTitle');
const brandSubtitle = document.getElementById('brandSubtitle');
const footerResourceName = document.getElementById('footerResourceName');

// UI text comes from the locale files in ../locales/<lang>.json (language set by Config.Locale in config.lua).
let locale = { status_ready: '', tips: [] };
let finished = false;
const timers = [];
const every = (fn, ms) => { const id = setInterval(fn, ms); timers.push(id); return id; };

let tipIndex = 0;
let tipInterval = null;
let tipDelay = 5000;

function applyLocale(data) {
  locale = data;

  brandTitle.textContent = locale.brand_title;
  brandSubtitle.textContent = locale.brand_subtitle;
  statusText.textContent = locale.status_loading;
  footerResourceName.textContent = locale.footer_resource_name;

  if (locale.tips.length) {
    tipText.textContent = locale.tips[0];
  }

  if (tipInterval) clearInterval(tipInterval);
  if (locale.tips.length < 2) return;
  tipInterval = every(() => {
    tipIndex = (tipIndex + 1) % locale.tips.length;
    tipText.style.opacity = 0;
    setTimeout(() => {
      tipText.textContent = locale.tips[tipIndex];
      tipText.style.opacity = 1;
    }, 250);
  }, tipDelay);
}

tipText.style.transition = 'opacity 0.25s ease';

// Background image(s) — "background_image" in config.json (or a theme's background) may be a
// single path/URL or a list for a slideshow. Images that fail to load are skipped.
function applyBackground(cfg) {
  const bg = document.getElementById('bg-image');
  if (!bg || !cfg) return;
  if (typeof cfg.background_dim === 'number') {
    bg.style.setProperty('--bg-dim', Math.max(0, Math.min(1, cfg.background_dim)));
  }
  const raw = cfg.background_image;
  const list = (Array.isArray(raw) ? raw : Object.values(raw && typeof raw === 'object' ? raw : { 1: raw }))
    .filter((v) => typeof v === 'string' && v);
  if (!list.length) return;
  let idx = 0;
  const show = (src, first) => {
    const img = new Image();
    img.onload = () => {
      const swap = () => {
        bg.style.backgroundImage = `url("${src}")`;
        bg.classList.add('loaded');
        bg.classList.remove('fading');
      };
      if (first) return swap();
      bg.classList.add('fading');
      setTimeout(swap, 800);
    };
    img.src = src;
  };
  show(list[0], true);
  const secs = typeof cfg.slideshow_seconds === 'number' ? cfg.slideshow_seconds : 12;
  if (list.length > 1 && secs > 0) {
    every(() => { idx = (idx + 1) % list.length; show(list[idx], false); }, secs * 1000);
  }
}

// Fill %s placeholders in order.
const fmt = (str, ...args) => { let n = 0; return String(str || '').replace(/%[sd]/g, () => args[n++] ?? ''); };

// News panel (ui_news_title + ui_news_1, ui_news_2 ...), live server info, discord and music.
function applyExtras(cfg, L) {
  const news = numbered(L, 'ui_news_');
  if (news.length) {
    document.getElementById('newsTitle').textContent = L.ui_news_title || '';
    const ul = document.getElementById('newsList');
    news.forEach((line) => { const li = document.createElement('li'); li.textContent = line; ul.appendChild(li); });
    document.getElementById('news').classList.remove('hidden');
  }

  const info = (window.nuiHandoverData || {}).rsgLoading;
  if (info) {
    document.getElementById('serverName').textContent = info.serverName || '';
    document.getElementById('playerCount').textContent = fmt(L.ui_players, info.players, info.maxPlayers);
    document.getElementById('serverInfo').classList.remove('hidden');
  }

  if (cfg.discord) {
    document.getElementById('discord').textContent = cfg.discord;
    document.getElementById('discord').classList.remove('hidden');
    document.getElementById('discordSep').classList.remove('hidden');
  }

  const music = document.getElementById('music');
  if (cfg.music && music) {
    music.src = cfg.music;
    music.volume = Math.max(0, Math.min(1, typeof cfg.music_volume === 'number' ? cfg.music_volume : 0.25));
    music.play().catch(() => {});
    const hint = document.getElementById('musicHint');
    hint.textContent = L.ui_music_hint || '';
    hint.classList.remove('hidden');
    window.addEventListener('keydown', (e) => {
      if (e.code !== 'Space') return;
      if (music.paused) music.play().catch(() => {}); else music.pause();
    });
  }
}

function fadeOutMusic() {
  const music = document.getElementById('music');
  if (!music || music.paused) return;
  const step = music.volume / 10;
  const id = setInterval(() => {
    music.volume = Math.max(0, music.volume - step);
    if (music.volume <= 0.001) { music.pause(); clearInterval(id); }
  }, 40);
}

const getJSON = (url) => fetch(url).then((r) => r.json()).catch(() => ({}));

// Collect numbered keys: prefix_1, prefix_2 ... (stops at the first gap)
function numbered(dict, prefix) {
  const out = [];
  for (let n = 1; dict[prefix + n] !== undefined; n++) out.push(dict[prefix + n]);
  return out;
}

// Load the selected ox_lib locale, with any missing keys filled from en.json.
function loadLocale(lang) {
  const code = String(lang || 'en').toLowerCase();
  const reqs = [getJSON('../locales/en.json')];
  if (code !== 'en') reqs.push(getJSON('../locales/' + code + '.json'));
  return Promise.all(reqs).then(([en, sel]) => Object.assign({}, en, sel || {}));
}

Promise.all([getJSON('config.json'), loadLuaConfig()]).then(([cfg, luaCfg]) => {
  if (typeof cfg.tip_interval_seconds === 'number' && cfg.tip_interval_seconds > 0) {
    tipDelay = cfg.tip_interval_seconds * 1000;
  }
  // Safety net: auto-close if the game never signals completion. 0 = disabled.
  const autoClose = typeof cfg.auto_close_seconds === 'number' ? cfg.auto_close_seconds : 120;
  if (autoClose > 0) setTimeout(finishLoading, autoClose * 1000);
  loadLocale(luaCfg.Locale).then((L) => {
    const lang = String(luaCfg.Locale || 'en');
    document.documentElement.lang = lang;
    document.title = L.ui_page_title || '';
    const text = {
      brand_title: L.ui_brand_title || '',
      brand_subtitle: L.ui_brand_subtitle || '',
      status_loading: L.ui_status_loading || '',
      status_ready: L.ui_status_ready || '',
      footer_resource_name: L.ui_footer_resource_name || '',
      tips: numbered(L, 'ui_tip_')
    };
    const picked = pickTheme(luaCfg);
    if (picked) {
      const { name, theme } = picked;
      const sub = L['theme_' + name + '_subtitle'];
      if (sub) text.brand_subtitle = sub;
      const tips = numbered(L, 'theme_' + name + '_tip_');
      if (tips.length) text.tips = luaCfg.MergeTips === false ? tips : tips.concat(text.tips);
      if (theme.background) cfg.background_image = theme.background;
      if (typeof theme.backgroundDim === 'number') cfg.background_dim = theme.backgroundDim;
      applyTheme(theme, luaCfg.Particles !== false, luaCfg.ParticleDensity);
    }
    applyLocale(text);
    applyBackground(cfg);
    applyExtras(cfg, L);
  });
});

/* ------------------------------------------------------------------ */
/* Seasonal themes (configured in ../config.lua)                       */
/* ------------------------------------------------------------------ */

// Minimal Lua literal parser: handles `Config = {}` / `Config.A.B = value`
// with strings, numbers, booleans, nil and nested tables. Comments ignored.
function parseLuaConfig(src) {
  const toks = [];
  let i = 0;
  while (i < src.length) {
    const c = src[i];
    if (/\s/.test(c)) { i++; continue; }
    if (src.startsWith('--', i)) {
      const m = src.slice(i).match(/^--\[(=*)\[/);
      if (m) { const end = src.indexOf(']' + m[1] + ']', i); i = end < 0 ? src.length : end + m[1].length + 2; }
      else { const nl = src.indexOf('\n', i); i = nl < 0 ? src.length : nl; }
      continue;
    }
    if (c === '"' || c === "'") {
      let j = i + 1, out = '';
      while (j < src.length && src[j] !== c) {
        if (src[j] === '\\') { j++; const e = src[j]; out += e === 'n' ? '\n' : e === 't' ? '\t' : e; }
        else out += src[j];
        j++;
      }
      toks.push({ t: 'str', v: out }); i = j + 1; continue;
    }
    const lb = src.slice(i).match(/^\[(=*)\[/);
    if (lb) { const end = src.indexOf(']' + lb[1] + ']', i); toks.push({ t: 'str', v: src.slice(i + lb[0].length, end).replace(/^\n/, '') }); i = end + lb[1].length + 2; continue; }
    const num = src.slice(i).match(/^-?(0x[0-9a-fA-F]+|\d+\.?\d*(e[+-]?\d+)?)/);
    if (num && (c === '-' ? /[\d]/.test(src[i + 1]) : true) && /[\d-]/.test(c)) { toks.push({ t: 'num', v: Number(num[0]) }); i += num[0].length; continue; }
    const id = src.slice(i).match(/^[A-Za-z_][A-Za-z0-9_]*/);
    if (id) { toks.push({ t: 'id', v: id[0] }); i += id[0].length; continue; }
    toks.push({ t: 'p', v: c }); i++;
  }
  let k = 0;
  const peek = () => toks[k] || {};
  const next = () => toks[k++] || {};
  const isP = (v) => peek().t === 'p' && peek().v === v;
  function value() {
    const tk = next();
    if (tk.t === 'str' || tk.t === 'num') return tk.v;
    if (tk.t === 'id') return tk.v === 'true' ? true : tk.v === 'false' ? false : null;
    if (tk.t === 'p' && tk.v === '{') {
      const arr = [], obj = {}; let isObj = false;
      while (!isP('}') && k < toks.length) {
        if (peek().t === 'id' && toks[k + 1] && toks[k + 1].v === '=') { const key = next().v; next(); obj[key] = value(); isObj = true; }
        else if (isP('[')) { next(); const key = value(); next(); next(); obj[key] = value(); isObj = true; }
        else arr.push(value());
        if (isP(',') || isP(';')) next();
      }
      next();
      if (!isObj) return arr;
      arr.forEach((v, n) => { obj[n + 1] = v; });
      return obj;
    }
    return null;
  }
  const root = {};
  while (k < toks.length) {
    if (peek().t !== 'id') { next(); continue; }
    const path = [next().v];
    while (isP('.')) { next(); path.push(next().v); }
    if (!isP('=')) continue;
    next();
    const v = value();
    if (path[0] !== 'Config') continue;
    let o = root;
    for (let p = 1; p < path.length - 1; p++) o = o[path[p]] = o[path[p]] || {};
    if (path.length === 1) Object.assign(root, v || {}); else o[path[path.length - 1]] = v;
  }
  return root;
}

function loadLuaConfig() {
  return fetch('../config.lua')
    .then((r) => r.text())
    .then(parseLuaConfig)
    .catch(() => ({}));
}

// Anonymous Gregorian algorithm
function easterSunday(year) {
  const a = year % 19, b = Math.floor(year / 100), c = year % 100;
  const d = Math.floor(b / 4), e = b % 4, f = Math.floor((b + 8) / 25);
  const g = Math.floor((b - f + 1) / 3), h = (19 * a + b - d - g + 15) % 30;
  const i = Math.floor(c / 4), k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7;
  const m = Math.floor((a + 11 * h + 22 * l) / 451);
  const month = Math.floor((h + l - 7 * m + 114) / 31);
  const day = ((h + l - 7 * m + 114) % 31) + 1;
  return new Date(year, month - 1, day);
}

function mmdd(str) {
  const [m, d] = String(str || '').split('-').map(Number);
  return m * 100 + d;
}

function themeActive(name, t, now) {
  if (!t || t.enabled === false) return false;
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  if (name === 'easter' && !t.start) {
    const day = 86400000;
    const e = easterSunday(now.getFullYear()).getTime();
    const from = e - (t.easterDaysBefore ?? 7) * day;
    const to = e + (t.easterDaysAfter ?? 1) * day;
    return today.getTime() >= from && today.getTime() <= to;
  }
  if (!t.start || !t.finish) return false;
  let cur = (now.getMonth() + 1) * 100 + now.getDate();
  if (cur === 229 && mmdd(t.finish) === 228) cur = 228; // leap day counts as Feb 28
  const s = mmdd(t.start), f = mmdd(t.finish);
  return s <= f ? cur >= s && cur <= f : cur >= s || cur <= f; // wraps new year
}

function pickTheme(cfg) {
  const themes = cfg.Themes || {};
  const seasons = cfg.Seasons || {};
  const mode = String(cfg.Theme || 'auto').toLowerCase();
  if (mode === 'default' || mode === 'none') return null;
  if (mode !== 'auto') {
    const t = themes[mode] || seasons[mode];
    return t ? { name: mode, theme: t } : null;
  }
  const now = new Date();
  for (const name of Object.keys(themes)) {
    if (themeActive(name, themes[name], now)) return { name, theme: themes[name] };
  }
  if (cfg.UseSeasons === false) return null;
  for (const name of Object.keys(seasons)) {
    if (themeActive(name, seasons[name], now)) return { name, theme: seasons[name] };
  }
  return null;
}

function applyTheme(t, particlesOn, density) {
  const c = t.colors || {};
  const root = document.documentElement.style;
  const set = (v, val) => { if (val) root.setProperty(v, val); };
  set('--theme-accent', c.accent);
  set('--theme-accent-2', c.accent2);
  set('--rdr-gold-dim', c.border);
  set('--rdr-panel', c.panel);
  set('--rdr-panel-2', c.panel2);
  set('--rdr-text', c.text);
  set('--rdr-muted', c.muted);
  document.body.classList.add('seasonal');
  const seal = document.querySelector('.brand-seal');
  const mark = document.querySelector('.divider .mark');
  if (t.seal && seal) seal.textContent = t.seal;
  if (t.divider && mark) mark.textContent = t.divider;
  if (particlesOn && t.particles) startParticles(String(t.particles), density);
}

function startParticles(kind, density) {
  const layer = document.getElementById('particles');
  if (!layer) return;
  let mult = typeof density === 'number' ? Math.max(0.1, Math.min(1, density)) : 1;
  if (window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches) mult = Math.min(mult, 0.3);
  if (kind === 'fireworks') return startFireworks(layer, mult);
  const glyph = { snow: '❄', bats: '🦇', petals: '✿', leaves: '❦', fireflies: '●' }[kind];
  if (!glyph) return;
  const count = Math.max(1, Math.round({ snow: 45, bats: 14, petals: 28, leaves: 30, fireflies: 35 }[kind] * mult));
  for (let n = 0; n < count; n++) {
    const p = document.createElement('span');
    p.className = 'particle particle-' + kind;
    p.textContent = glyph;
    p.style.left = Math.random() * 100 + 'vw';
    p.style.fontSize = (kind === 'bats' ? 14 + Math.random() * 16 : kind === 'fireflies' ? 3 + Math.random() * 4 : 8 + Math.random() * 14) + 'px';
    if (kind === 'fireflies') p.style.top = 30 + Math.random() * 65 + 'vh';
    if (kind === 'leaves') p.style.color = ['#c8501e', '#e07a1f', '#d9a028', '#a8321c'][n % 4];
    p.style.opacity = (0.35 + Math.random() * 0.55).toFixed(2);
    p.style.animationDuration = (kind === 'bats' ? 7 + Math.random() * 8 : 9 + Math.random() * 12) + 's';
    p.style.animationDelay = -Math.random() * 20 + 's';
    layer.appendChild(p);
  }
}

function startFireworks(layer, mult = 1) {
  const colors = ['#ffd86b', '#ff5e8a', '#6bd5ff', '#b98bff', '#7dff9a', '#ffffff', '#ff9e4a'];
  function burst() {
    const x = 10 + Math.random() * 80;   // vw
    const y = 10 + Math.random() * 45;   // vh (upper half of screen)
    const color = colors[Math.floor(Math.random() * colors.length)];
    const rocket = document.createElement('span');
    rocket.className = 'fw-rocket';
    rocket.style.left = x + 'vw';
    rocket.style.setProperty('--fw-rise', (100 - y) + 'vh');
    rocket.style.background = color;
    layer.appendChild(rocket);
    setTimeout(() => {
      rocket.remove();
      const sparks = Math.max(8, Math.round((26 + Math.floor(Math.random() * 18)) * mult));
      const radius = 70 + Math.random() * 90;
      for (let n = 0; n < sparks; n++) {
        const a = (n / sparks) * Math.PI * 2 + Math.random() * 0.2;
        const r = radius * (0.75 + Math.random() * 0.25);
        const s = document.createElement('span');
        s.className = 'fw-spark';
        s.style.left = x + 'vw';
        s.style.top = y + 'vh';
        s.style.background = color;
        s.style.boxShadow = `0 0 6px ${color}, 0 0 12px ${color}`;
        s.style.setProperty('--fw-x', Math.cos(a) * r + 'px');
        s.style.setProperty('--fw-y', Math.sin(a) * r + 'px');
        layer.appendChild(s);
        setTimeout(() => s.remove(), 1700);
      }
    }, 900);
  }
  burst();
  every(() => {
    if (document.hidden) return;
    burst();
    if (Math.random() < 0.4 * mult) setTimeout(burst, 250 + Math.random() * 400);
  }, (900 + Math.random() * 600) / Math.max(mult, 0.5));
}

function updateClock() {
  const now = new Date();
  const h = String(now.getHours()).padStart(2, '0');
  const m = String(now.getMinutes()).padStart(2, '0');
  clockEl.textContent = `${h}:${m}`;
}
updateClock();
every(updateClock, 1000 * 30);

// Fallback simulated progress in case loadProgress events never fire
// (e.g. previewing this loading screen outside of RedM).
let simulated = 0;
let receivedRealProgress = false;
const simInterval = every(() => {
  if (receivedRealProgress || finished) {
    clearInterval(simInterval);
    return;
  }
  simulated = Math.min(simulated + Math.random() * 4, 96);
  setProgress(simulated);
}, 200);

function setProgress(pct) {
  pct = Math.max(0, Math.min(100, pct));
  progressFill.style.width = pct + '%';
  percentText.textContent = Math.floor(pct) + '%';
}

window.addEventListener('message', (event) => {
  const data = event.data || {};

  // Native RedM/FiveM loadProgress event: { loadFraction: 0..1 }
  if (typeof data.loadFraction === 'number' && !finished) {
    receivedRealProgress = true;
    setProgress(data.loadFraction * 100);
  }

  // Native onLoadDone-ish signal / custom "endLoading" NUI message
  if (data.eventName === 'endLoading' || data.type === 'endLoading') {
    finishLoading();
  }

  if (typeof data.statusText === 'string') {
    statusText.textContent = data.statusText;
  }
});

function finishLoading() {
  if (finished) return;
  finished = true;
  timers.forEach(clearInterval);
  setProgress(100);
  statusText.textContent = locale.status_ready;
  fadeOutMusic();
  setTimeout(() => {
    const layer = document.getElementById('particles');
    if (layer) layer.replaceChildren();
    if (window.invokeNative) {
      window.invokeNative('shutdownLoadingScreenNui');
    }
    document.getElementById('root').classList.add('hidden');
  }, 400);
}

