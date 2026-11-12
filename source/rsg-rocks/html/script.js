const app = document.getElementById('app');
const list = document.getElementById('rocks');
let L = {}, state = { maxBatch: 50, firstTime: 10000, perRock: 4000 };
const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-rocks';

function post(name, data = {}) {
    fetch(`https://${res}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) }).catch(() => {});
}
function fmtTime(ms) {
    const s = Math.round(ms / 1000), m = Math.floor(s / 60);
    return m > 0 ? `${m}m ${s % 60}s` : `${s}s`;
}
function batchTime(n) { return state.firstTime + Math.max(0, n - 1) * state.perRock; }
function esc(t) { const d = document.createElement('div'); d.textContent = t ?? ''; return d.innerHTML; }

function render(rocks) {
    list.innerHTML = '';
    rocks.forEach(r => {
        const max = Math.min(r.count, state.maxBatch);
        const row = document.createElement('div');
        row.className = 'row' + (r.count < 1 ? ' disabled' : '');
        const img = r.image ? `<img src="nui://rsg-inventory/html/images/${esc(r.image)}" onerror="this.remove()">` : '';
        row.innerHTML = `
            <div class="row-top">
                <div class="badge-icon">${img}</div>
                <div class="info"><div class="name">${esc(r.label)}</div><div class="desc">${esc(L.owned)}: ${r.count}</div></div>
                <span class="pill">x${r.count}</span>
            </div>
            ${r.count < 1 ? `<div class="desc" style="margin-top:8px">${esc(L.none)}</div>` : `
            <div class="controls">
                <div class="stepper"><button data-d="-1">−</button><input type="number" value="1" min="1" max="${max}"><button data-d="1">+</button></div>
                <button class="wood-btn" data-act="drill">${esc(L.drill)}</button>
                <button class="wood-btn muted" data-act="all">${esc(L.drillAll)} (${max})</button>
            </div>
            <div class="time"></div>`}`;
        list.appendChild(row);
        if (r.count < 1) return;
        const input = row.querySelector('input'), time = row.querySelector('.time');
        const clamp = () => {
            let v = parseInt(input.value, 10); if (isNaN(v)) v = 1;
            input.value = Math.max(1, Math.min(max, v));
            time.textContent = `${L.time}: ${fmtTime(batchTime(+input.value))}`;
        };
        clamp();
        input.addEventListener('input', clamp);
        row.querySelectorAll('.stepper button').forEach(b => b.addEventListener('click', () => { input.value = +input.value + +b.dataset.d; clamp(); }));
        row.querySelector('[data-act="drill"]').addEventListener('click', () => post('drill', { item: r.item, amount: +input.value }));
        row.querySelector('[data-act="all"]').addEventListener('click', () => post('drill', { item: r.item, all: true }));
    });
}

window.addEventListener('message', e => {
    const d = e.data;
    if (d.action === 'open') {
        L = d.locale || {};
        state = { maxBatch: d.maxBatch, firstTime: d.firstTime, perRock: d.perRock };
        document.getElementById('title').textContent = L.title;
        document.getElementById('subtitle').textContent = L.subtitle;
        document.getElementById('closeBtn').title = L.close;
        render(d.rocks || []);
        app.classList.remove('hidden');
    } else if (d.action === 'close') {
        app.classList.add('hidden');
    }
});
document.getElementById('closeBtn').addEventListener('click', () => post('close'));
document.addEventListener('keyup', e => { if (app.classList.contains('hidden')) return; if (e.key === 'Escape' || e.key === 'Backspace' && e.target.tagName !== 'INPUT') post('close'); });
