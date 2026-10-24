const banner = document.getElementById('banner');
const titleEl = document.getElementById('title');
const infoEl = document.getElementById('info');
let hideTimer, removeTimer;

function show(data) {
    clearTimeout(hideTimer); clearTimeout(removeTimer);
    titleEl.textContent = data.title || '';
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

window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'show') show(d);
    else if (d.action === 'hide') { clearTimeout(hideTimer); banner.classList.add('hidden'); }
});
