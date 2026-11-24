const banner = document.getElementById('banner');
const titleEl = document.getElementById('title');
const infoEl = document.getElementById('info');
const stampEl = document.getElementById('stamp');
const flavourEl = document.getElementById('flavour');
let hideTimer, removeTimer;
let playing = false;
const queue = []; // banners waiting for the current one to finish (Config.BannerQueue)

// long place names ("Settlement Fort Riggs Holding Camp") shrink to fit instead of running off screen
function fitTitle() {
    titleEl.style.fontSize = '';
    const maxW = window.innerWidth * 0.7 - 80;
    let size = parseFloat(getComputedStyle(titleEl).fontSize) || 40;
    banner.style.visibility = 'hidden';
    banner.classList.remove('hidden');
    while (titleEl.scrollWidth > maxW && size > 18) { size -= 2; titleEl.style.fontSize = size + 'px'; }
    banner.style.visibility = '';
}

function show(data) {
    if (data.queue && playing) {
        queue.push({ data, at: Date.now() });
        while (queue.length > 3) queue.shift();
        return;
    }
    play(data);
}

function next() {
    playing = false;
    while (queue.length) {
        const q = queue.shift();
        if (Date.now() - q.at < 15000) { play(q.data); return; } // skip banners that waited too long
    }
}

function play(data) {
    playing = true;
    clearTimeout(hideTimer); clearTimeout(removeTimer);
    titleEl.textContent = data.title || '';
    stampEl.textContent = data.stamp || '';
    stampEl.classList.toggle('hidden', !data.stamp);
    flavourEl.textContent = data.flavour || '';
    flavourEl.classList.toggle('hidden', !data.flavour);
    infoEl.innerHTML = '';
    (data.parts || []).forEach((p, i) => {
        if (i > 0) { const s = document.createElement('span'); s.className = 'sep'; s.textContent = '|'; infoEl.appendChild(s); }
        const span = document.createElement('span');
        span.textContent = p.text; span.style.color = p.color || '#f2f2f2';
        infoEl.appendChild(span);
    });
    infoEl.classList.toggle('hidden', !(data.parts && data.parts.length));
    banner.classList.remove('hidden', 'show', 'leave');
    fitTitle();
    void banner.offsetWidth;
    banner.classList.add('show');
    hideTimer = setTimeout(() => {
        banner.classList.remove('show'); banner.classList.add('leave');
        removeTimer = setTimeout(() => { banner.classList.add('hidden'); next(); }, 650);
    }, data.duration || 5000);
}

// soft built-in chime (no audio files needed); custom files go in html/sounds/
let audioCtx;
const CHIMES = { state: [392, 523.25, 659.25], district: [440, 587.33], town: [523.25, 659.25], landmark: [587.33, 739.99], discovery: [523.25, 659.25, 783.99, 1046.5], manual: [659.25], custom: [523.25, 783.99] };
function chime(kind, volume) {
    try {
        audioCtx = audioCtx || new (window.AudioContext || window.webkitAudioContext)();
        if (audioCtx.state === 'suspended') audioCtx.resume();
        const notes = CHIMES[kind] || CHIMES.manual;
        const t0 = audioCtx.currentTime;
        notes.forEach((f, i) => {
            const o = audioCtx.createOscillator(), g = audioCtx.createGain();
            o.type = 'sine'; o.frequency.value = f;
            const s = t0 + i * 0.12;
            g.gain.setValueAtTime(0, s);
            g.gain.linearRampToValueAtTime(volume, s + 0.02);
            g.gain.exponentialRampToValueAtTime(0.0001, s + 1.2);
            o.connect(g).connect(audioCtx.destination);
            o.start(s); o.stop(s + 1.25);
        });
    } catch (e) { /* audio not available */ }
}
function playSound(d) {
    if (d.file === false) return;
    const vol = Math.min(Math.max(Number(d.volume) || 0.25, 0), 1);
    if (typeof d.file === 'string' && d.file !== '') {
        const a = new Audio(d.file); a.volume = vol;
        a.play().catch(() => chime(d.kind, vol));
    } else chime(d.kind, vol);
}

window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'show') show(d);
    else if (d.action === 'sound') playSound(d);
    else if (d.action === 'hide') { queue.length = 0; playing = false; clearTimeout(hideTimer); clearTimeout(removeTimer); banner.classList.remove('show', 'leave'); banner.classList.add('hidden'); }
});
