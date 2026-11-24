// rsg-zonenotify journal (NUI). Text comes from the game's locale files via the 'journal' message.
(() => {
    const root = document.getElementById('journal');
    const tabsEl = document.getElementById('jTabs');
    const bodyEl = document.getElementById('jBody');
    let data = null;
    let tab = 'overview';

    const post = (name, payload) =>
        fetch(`https://${GetParentResourceName()}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(payload || {}),
        }).then((r) => r.json()).catch(() => null);

    const el = (tag, cls, text) => {
        const e = document.createElement(tag);
        if (cls) e.className = cls;
        if (text !== undefined && text !== null) e.textContent = text;
        return e;
    };
    const pct = (a, b) => (b > 0 ? Math.floor((a / b) * 100) : 0);
    const rewardText = (cash, xp) => [cash > 0 ? '$' + cash : '', xp > 0 ? xp + ' XP' : ''].filter(Boolean).join(' · ');

    function bar(found, total) {
        const b = el('div', 'bar');
        const f = el('div', 'fill' + (found >= total && total > 0 ? ' stat-good' : ''));
        b.appendChild(f);
        requestAnimationFrame(() => { f.style.width = pct(found, total) + '%'; });
        return b;
    }

    function rewardPill(reward, claimed) {
        if (claimed) return el('div', 'pill done', data.text.claimed);
        if (reward && (reward.cash > 0 || reward.xp > 0)) return el('div', 'pill', rewardText(reward.cash, reward.xp));
        return null;
    }

    function renderHeader() {
        document.getElementById('jTitle').textContent = data.text.title;
        document.getElementById('jSubtitle').textContent = data.text.subtitle;
        document.getElementById('jClose').title = data.text.close;
        document.getElementById('jOverallText').textContent = data.found + ' / ' + data.total;
        document.getElementById('jOverallPct').textContent = pct(data.found, data.total) + '%';
        const fill = document.getElementById('jOverallFill');
        fill.className = 'fill' + (data.found >= data.total && data.total > 0 ? ' stat-good' : '');
        requestAnimationFrame(() => { fill.style.width = pct(data.found, data.total) + '%'; });
    }

    function tabList() {
        const list = [];
        if (data.categories.length) list.push({ id: 'overview', label: data.text.overall });
        data.categories.forEach((c) => list.push({ id: c.kind, label: c.label }));
        if (data.showLeaderboard) list.push({ id: 'leaderboard', label: data.text.tab_leaderboard });
        list.push({ id: 'options', label: data.text.tab_options });
        return list;
    }

    function renderTabs() {
        tabsEl.innerHTML = '';
        tabList().forEach((t) => {
            const b = el('button', 'tab' + (t.id === tab ? ' active' : ''), t.label);
            b.onclick = () => { tab = t.id; render(); };
            tabsEl.appendChild(b);
        });
    }

    function renderOverview() {
        data.categories.forEach((c) => {
            const row = el('div', 'row link');
            row.onclick = () => { tab = c.kind; render(); };
            row.appendChild(el('div', 'badge-icon', '✦'));
            const mid = el('div', 'grow');
            mid.appendChild(el('div', 'r-title', c.label));
            mid.appendChild(bar(c.found, c.total));
            row.appendChild(mid);
            row.appendChild(el('div', 'count', c.found + ' / ' + c.total));
            const pill = rewardPill(c.reward, c.claimed);
            if (pill) row.appendChild(pill);
            bodyEl.appendChild(row);
        });
        if (data.overall.length) {
            bodyEl.appendChild(el('div', 'section', '✦ ' + data.text.milestones + ' ✦'));
            const chips = el('div', 'chips');
            data.overall.forEach((m) => {
                const reached = data.found * 100 >= data.total * m.percent;
                const chip = el('div', 'pill' + (m.claimed || reached ? ' done' : ''), m.percent + '%  ' + rewardText(m.cash, m.xp));
                chips.appendChild(chip);
            });
            bodyEl.appendChild(chips);
        }
    }

    function renderCategory(c) {
        const row = el('div', 'row');
        row.appendChild(el('div', 'badge-icon', '✦'));
        const mid = el('div', 'grow');
        mid.appendChild(el('div', 'r-title', c.label));
        mid.appendChild(bar(c.found, c.total));
        row.appendChild(mid);
        row.appendChild(el('div', 'count', c.found + ' / ' + c.total));
        const pill = rewardPill(c.reward, c.claimed);
        if (pill) row.appendChild(pill);
        bodyEl.appendChild(row);

        const grid = el('div', 'grid');
        c.places.forEach((p) => {
            const d = el('div', 'place' + (p.found ? '' : ' missing'));
            d.appendChild(el('span', 'mark', p.found ? '✓' : '·'));
            d.appendChild(el('span', '', p.name));
            grid.appendChild(d);
        });
        bodyEl.appendChild(grid);
    }

    function renderLeaderboard() {
        if (!data.leaderboard.length) { bodyEl.appendChild(el('div', 'empty', data.text.lb_empty)); return; }
        data.leaderboard.forEach((r) => {
            const row = el('div', 'row' + (r.me ? ' me' : ''));
            row.appendChild(el('div', 'badge-icon', String(r.rank)));
            const mid = el('div', 'grow');
            mid.appendChild(el('div', 'r-title', r.name));
            row.appendChild(mid);
            if (r.me) row.appendChild(el('div', 'pill you', data.text.you));
            row.appendChild(el('div', 'count', r.found + ' ' + data.text.places));
            bodyEl.appendChild(row);
        });
    }

    function renderOptions() {
        const opts = [['banners', 'opt_banners'], ['sound', 'opt_sound'], ['time', 'opt_time'], ['temperature', 'opt_temperature'], ['wind', 'opt_wind']];
        opts.forEach(([key, label]) => {
            if (!data.toggles[key]) return;
            const row = el('div', 'row');
            const mid = el('div', 'grow');
            mid.appendChild(el('div', 'r-title', data.text[label]));
            row.appendChild(mid);
            row.appendChild(el('div', 'pill', data.prefs[key] ? data.text.on : data.text.off));
            const sw = el('div', 'switch' + (data.prefs[key] ? ' on' : ''));
            sw.onclick = () => {
                const value = !data.prefs[key];
                data.prefs[key] = value; // optimistic; the game confirms the saved values
                post('journalPref', { key, value }).then((saved) => { if (saved) data.prefs = saved; render(); });
                render();
            };
            row.appendChild(sw);
            bodyEl.appendChild(row);
        });
    }

    function render() {
        if (!data) return;
        if (!tabList().some((t) => t.id === tab)) tab = tabList()[0].id;
        const keepScroll = bodyEl.scrollTop;
        renderHeader();
        renderTabs();
        bodyEl.innerHTML = '';
        if (tab === 'overview') renderOverview();
        else if (tab === 'leaderboard') renderLeaderboard();
        else if (tab === 'options') renderOptions();
        else renderCategory(data.categories.find((c) => c.kind === tab));
        bodyEl.scrollTop = keepScroll;
    }

    function open(d) {
        data = d;
        tab = d.tab && tabList().some((t) => t.id === d.tab) ? d.tab : tabList()[0].id;
        bodyEl.scrollTop = 0;
        root.classList.remove('hidden');
        render();
    }

    function close() {
        root.classList.add('hidden');
        data = null;
    }

    document.getElementById('jClose').onclick = () => post('journalClose');
    document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && data) post('journalClose'); });
    window.addEventListener('message', (e) => {
        const d = e.data || {};
        if (d.action === 'journal') open(d);
        else if (d.action === 'journalClose') close();
    });
})();
