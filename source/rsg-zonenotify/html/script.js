const banner = document.getElementById('banner');
const titleEl = document.getElementById('title');
const infoEl = document.getElementById('info');
const stampEl = document.getElementById('stamp');
const flavourEl = document.getElementById('flavour');
let hideTimer, removeTimer;

function show(data) {
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
    void banner.offsetWidth;
    banner.classList.add('show');
    hideTimer = setTimeout(() => {
        banner.classList.remove('show'); banner.classList.add('leave');
        removeTimer = setTimeout(() => banner.classList.add('hidden'), 650);
    }, data.duration || 5000);
}

// soft built-in chime (no audio files needed); custom files go in html/sounds/
let audioCtx;
const CHIMES = { state: [392, 523.25, 659.25], district: [440, 587.33], town: [523.25, 659.25], landmark: [587.33, 739.99], discovery: [523.25, 659.25, 783.99, 1046.5], manual: [659.25], custom: [523.25, 783.99] };
function chime(kind, volume) {
    try {
        audioCtx = audioCtx || new (window.AudioContext || window.webkitAudioContext)();
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
    else if (d.action === 'hide') { clearTimeout(hideTimer); banner.classList.add('hidden'); }
});
