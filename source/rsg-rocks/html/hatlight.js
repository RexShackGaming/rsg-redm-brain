(() => {
    const COLORS = ['#ffd9a0', '#fff4e0', '#ffffff', '#ffb347', '#ff7a3d', '#ff4040',
                    '#ffe066', '#9be37a', '#5ad1c9', '#7ab8ff', '#9a7aff', '#ff7ad9'];
    const panel = document.getElementById('hatPanel');
    const head = document.getElementById('hatHead');
    const bright = document.getElementById('hatBright'), spread = document.getElementById('hatSpread');
    const brightVal = document.getElementById('hatBrightVal'), spreadVal = document.getElementById('hatSpreadVal');
    const toggle = document.getElementById('hatToggle'), done = document.getElementById('hatDone');
    const hint = document.getElementById('hatHint'), swatches = document.getElementById('swatches');
    const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-rocks';
    let S = {}, L = {}, focus = false, sendTimer = null;

    const post = (n, d = {}) => fetch(`https://${res}/${n}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(d) }).catch(() => {});
    const send = () => { clearTimeout(sendTimer); sendTimer = setTimeout(() => post('hatSettings', S), 80); };

    COLORS.forEach(c => {
        const el = document.createElement('div');
        el.className = 'swatch'; el.style.background = c; el.dataset.c = c;
        el.addEventListener('click', () => { S.color = c; paint(); send(); });
        swatches.appendChild(el);
    });

    function paint() {
        bright.value = S.bright; spread.value = S.spread;
        brightVal.textContent = `${Math.round(S.bright)}%`;
        spreadVal.textContent = `${(+S.spread).toFixed(1)}m`;
        toggle.textContent = S.on ? L.on : L.off;
        toggle.classList.toggle('off', !S.on);
        swatches.querySelectorAll('.swatch').forEach(s => s.classList.toggle('sel', s.dataset.c === S.color));
    }
    let worn = false;
    function setFocus(f) {
        focus = f && worn;
        // panel only shows while adjusting (/minerlight)
        panel.classList.toggle('hidden', !focus);
        panel.classList.toggle('focus', focus);
        done.classList.toggle('hidden', !f);
        hint.classList.toggle('hidden', f);
    }
    function placeAt(x, y) {
        const maxX = window.innerWidth - panel.offsetWidth, maxY = window.innerHeight - panel.offsetHeight;
        panel.style.left = Math.max(0, Math.min(maxX, x)) + 'px';
        panel.style.top = Math.max(0, Math.min(maxY, y)) + 'px';
    }

    bright.addEventListener('input', () => { S.bright = +bright.value; paint(); send(); });
    spread.addEventListener('input', () => { S.spread = +spread.value; paint(); send(); });
    toggle.addEventListener('click', () => { S.on = !S.on; paint(); send(); });
    done.addEventListener('click', () => post('hatClose'));

    // drag by the header while focused
    let drag = null;
    head.addEventListener('mousedown', e => {
        if (!focus || e.target === toggle) return;
        const r = panel.getBoundingClientRect();
        drag = { dx: e.clientX - r.left, dy: e.clientY - r.top };
    });
    document.addEventListener('mousemove', e => { if (drag) placeAt(e.clientX - drag.dx, e.clientY - drag.dy); });
    document.addEventListener('mouseup', () => {
        if (!drag) return;
        drag = null;
        const r = panel.getBoundingClientRect();
        post('hatMoved', { x: Math.round(r.left), y: Math.round(r.top) });
    });
    document.addEventListener('keyup', e => { if (focus && e.key === 'Escape') post('hatClose'); });

    window.addEventListener('message', e => {
        const d = e.data;
        if (d.action === 'hatPanel') {
            worn = !!d.show;
            if (!worn) { setFocus(false); return; }
            S = Object.assign({}, d.settings); L = d.locale || {};
            spread.min = d.minSpread; spread.max = d.maxSpread;
            document.getElementById('hatTitle').textContent = L.title;
            document.getElementById('hatColorLbl').textContent = L.color;
            document.getElementById('hatBrightLbl').textContent = L.bright;
            document.getElementById('hatSpreadLbl').textContent = L.spread;
            hint.textContent = L.hint; done.textContent = L.done;
            paint(); setFocus(false);
        } else if (d.action === 'hatFocus') {
            setFocus(!!d.focus);
            if (focus && S.x != null && S.y != null) placeAt(S.x, S.y); // needs the panel visible to measure
        }
    });
})();
