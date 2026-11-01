(() => {
    const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-hunting';
    const post = (ep, data = {}) => fetch(`https://${res}/${ep}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data)
    }).catch(() => {});
    const el = (id) => document.getElementById(id);
    const esc = (s) => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const fmt = (s, ...a) => { let i = 0; return String(s ?? '').replace(/%s/g, () => a[i++] ?? '').replace(/%%/g, '%'); };

    const board = el('board');
    const header = el('board-header');
    const POS_KEY = 'rsg-hunting:boardPos';
    let L = {};
    let pinned = false;
    let mode = 'all';

    // ---------- position (saved per client) ----------
    function clamp(x, y) {
        const r = board.getBoundingClientRect();
        return [Math.min(Math.max(0, x), window.innerWidth - r.width), Math.min(Math.max(0, y), window.innerHeight - 40)];
    }
    function applyPos(x, y) { [x, y] = clamp(x, y); board.style.left = x + 'px'; board.style.top = y + 'px'; }
    function savePos() {
        try { localStorage.setItem(POS_KEY, JSON.stringify({ x: board.offsetLeft, y: board.offsetTop })); } catch (e) {}
    }
    function loadPos() {
        try {
            const p = JSON.parse(localStorage.getItem(POS_KEY) || 'null');
            if (p && typeof p.x === 'number') { applyPos(p.x, p.y); return; }
        } catch (e) {}
        board.style.left = ''; board.style.top = '';
    }

    // ---------- dragging ----------
    let drag = null;
    header.addEventListener('mousedown', (e) => {
        if (pinned || e.button !== 0 || e.target.closest('.round-btn')) return;
        drag = { dx: e.clientX - board.offsetLeft, dy: e.clientY - board.offsetTop };
        board.classList.add('dragging');
        e.preventDefault();
    });
    document.addEventListener('mousemove', (e) => { if (drag) applyPos(e.clientX - drag.dx, e.clientY - drag.dy); });
    document.addEventListener('mouseup', () => {
        if (!drag) return;
        drag = null; board.classList.remove('dragging'); savePos();
    });
    // double-click header to reset position
    header.addEventListener('dblclick', (e) => {
        if (pinned || e.target.closest('.round-btn')) return;
        try { localStorage.removeItem(POS_KEY); } catch (err) {}
        board.style.left = ''; board.style.top = '';
    });
    window.addEventListener('resize', () => { if (!board.classList.contains('hidden')) applyPos(board.offsetLeft, board.offsetTop); });

    // ---------- render ----------
    function render(d) {
        L = d.labels || L;
        el('board-grip').title = L.drag || '';
        el('board-pin').title = L.pin || '';
        el('board-close').title = L.close || '';
        el('board-title').textContent = L.title;
        el('board-sub').textContent = fmt(L.total, d.total);
        mode = d.mode || 'all';
        el('tab-all').textContent = L.allTime || '';
        el('tab-weekly').textContent = L.weekly || '';
        el('board-tabs').classList.toggle('hidden', !d.weeklyEnabled);
        document.querySelectorAll('.board-tab').forEach(t => t.classList.toggle('active', t.dataset.mode === mode));

        const me = d.me;
        el('board-me-rank').textContent = me.rank ? '#' + me.rank : L.unranked;
        el('board-me-level').textContent = fmt(L.level, me.level, me.label);
        const toNext = me.nextXP ? fmt(L.next, me.nextXP - me.xp) : L.maxed;
        el('board-me-xp').textContent = mode === 'weekly'
            ? `${fmt(L.weekXP, me.weekXP || 0)} · ${fmt(L.xp, me.xp)}`
            : `${fmt(L.xp, me.xp)} · ${toNext}`;
        const pct = me.nextXP ? Math.max(0, Math.min(100, ((me.xp - me.levelXP) / (me.nextXP - me.levelXP)) * 100)) : 100;
        const fill = el('board-me-fill');
        fill.style.width = pct + '%';
        fill.classList.toggle('stat-warn', !me.nextXP);

        const p = me.perks || {};
        el('board-perks').innerHTML =
            `<span class="pill">${esc(L.trapper)} <b>+${p.trapperBonus || 0}%</b></span>` +
            `<span class="pill">${esc(L.butcher)} <b>+${p.butcherBonus || 0}%</b></span>` +
            `<span class="pill">${esc(L.extraSkin)} <b>${p.extraSkinChance || 0}%</b></span>`;

        const extra = [];
        if (d.bounties && d.bounties.length) {
            extra.push(`<div class="extra-line"><span class="extra-label">${esc(L.bounties)}</span><b>${d.bounties.map(esc).join(', ')}</b></div>`);
        }
        if (mode === 'weekly' && d.rewards && d.rewards.length) {
            extra.push(`<div class="extra-line"><span class="extra-label">${esc(L.rewards)}</span>${d.rewards.map((c, i) => `#${i + 1} <b>$${Number(c).toFixed(2)}</b>`).join(' · ')}</div>`);
        }
        if (d.unclaimed > 0) {
            extra.push(`<div class="extra-line claim"><span class="extra-label">${esc(L.unclaimed)}</span><b>$${Number(d.unclaimed).toFixed(2)}</b></div>`);
        }
        el('board-extra').innerHTML = extra.join('');

        const list = el('board-list');
        if (!d.top.length) { list.innerHTML = `<div class="board-empty">${esc(L.empty)}</div>`; return; }
        list.innerHTML = d.top.map(e => `
            <div class="board-row rank-${e.rank}${e.me ? ' me' : ''}">
                <div class="rank-badge">${e.rank}</div>
                <div class="row-main">
                    <div class="row-name">${esc(e.name)}</div>
                    ${e.level ? `<div class="row-sub">${esc(fmt(L.level, e.level, e.label))}</div>` : ''}
                </div>
                <div class="row-xp">${esc(fmt(L.xp, e.xp))}</div>
            </div>`).join('');
    }

    function setPinned(v) {
        pinned = v;
        board.classList.toggle('pinned', v);
        el('board-pin').classList.toggle('active', v);
        el('board-hint').classList.toggle('hidden', v);
    }

    function close(notify = true) {
        board.classList.add('hidden');
        setPinned(false);
        drag = null;
        if (notify) post('boardClose');
    }

    window.addEventListener('message', (e) => {
        const d = e.data || {};
        if (d.action === 'boardOpen') {
            board.classList.remove('hidden');
            setPinned(false);
            render(d);
            el('board-hint').textContent = L.hint || '';
            loadPos();
        } else if (d.action === 'boardUpdate') {
            render(d);
        } else if (d.action === 'boardClose') {
            close(false);
        }
    });

    el('board-close').addEventListener('click', () => close());
    document.querySelectorAll('.board-tab').forEach(t => t.addEventListener('click', () => {
        if (pinned || t.dataset.mode === mode) return;
        post('boardMode', { mode: t.dataset.mode });
    }));
    el('board-pin').addEventListener('click', () => {
        // pin = keep it on screen as an overlay and hand control back to the game
        setPinned(true);
        post('boardPin');
    });

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && !board.classList.contains('hidden') && !pinned) close();
    });
})();
