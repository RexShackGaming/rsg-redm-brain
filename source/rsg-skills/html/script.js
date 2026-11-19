(() => {
    const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-skills';
    const post = (ep, data = {}) => fetch(`https://${res}/${ep}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).then(r => r.json()).catch(() => ({}));

    const $ = (id) => document.getElementById(id);
    const app = $('app');

    let L = {};
    const state = { skills: [], tab: 'skills', mode: 'all', skill: 'all', weeklyEnabled: true, token: 0 };

    const fmt = (n) => Number(n || 0).toLocaleString('en-US');
    // replaces %s / %d placeholders in order
    const fmtStr = (str, ...args) => {
        let i = 0;
        return String(str || '').replace(/%[sd]/g, () => (i < args.length ? args[i++] : ''));
    };
    // text is always set with textContent, never innerHTML (player names come from the server)
    const el = (tag, cls, text) => {
        const e = document.createElement(tag);
        if (cls) e.className = cls;
        if (text !== undefined && text !== null) e.textContent = text;
        return e;
    };

    /* ---------- skills tab ---------- */
    function renderSkills(data) {
        $('sum-level').textContent = `${data.totalLevel} / ${data.maxTotalLevel}`;
        $('sum-xp').textContent = fmt(data.totalXP);

        const boost = $('boost');
        if (data.boost) {
            boost.textContent = fmtStr(L.boost, data.boost.mult, data.boost.minutes);
            boost.classList.remove('hidden');
        } else {
            boost.classList.add('hidden');
        }

        const list = $('skill-list');
        list.replaceChildren();
        data.skills.forEach((s) => {
            const row = el('div', 'row skill');
            row.appendChild(el('div', 'badge', s.level));

            const main = el('div', 'skill-main');
            const top = el('div', 'skill-top');
            top.appendChild(el('span', 'skill-name', s.label));
            top.appendChild(el('span', 'pill', s.rank));
            main.appendChild(top);
            if (s.description) main.appendChild(el('div', 'skill-desc', s.description));

            const bar = el('div', 'bar');
            const fill = el('div', 'bar-fill' + (s.nextXP ? '' : ' stat-good'));
            fill.style.width = `${s.pct}%`;
            bar.appendChild(fill);
            main.appendChild(bar);

            const text = el('div', 'bar-text');
            text.appendChild(el('span', '', `${fmt(s.xp)} ${L.xp}`));
            text.appendChild(el('span', '', s.nextXP
                ? fmtStr(L.next, fmt(s.nextXP - s.xp), s.level + 1)
                : L.maxed));
            main.appendChild(text);

            if (s.perks && s.perks.length) {
                const perks = el('div', 'perks');
                s.perks.forEach((p) => {
                    const line = el('div', 'perk');
                    line.appendChild(el('span', 'perk-name', p.label));
                    const val = el('span', 'perk-value' + (p.value ? '' : ' off'), p.value ? `+${p.value}${p.suffix || ''}` : '—');
                    if (p.nextLevel) {
                        val.appendChild(el('span', 'perk-next', fmtStr(L.unlocksAt, p.nextLevel, `+${p.nextValue}${p.suffix || ''}`)));
                    }
                    line.appendChild(val);
                    perks.appendChild(line);
                });
                main.appendChild(perks);
            }

            row.appendChild(main);
            list.appendChild(row);
        });
    }

    /* ---------- dropdown (pure HTML) ---------- */
    const dd = $('dd-skill');
    const ddMenu = $('dd-skill-menu');

    function closeDd() {
        dd.classList.remove('open');
        ddMenu.classList.add('hidden');
    }

    function setupSkillDd() {
        const options = [{ value: 'all', label: L.boardOverall }]
            .concat(state.skills.map((s) => ({ value: s.key, label: s.label })));
        ddMenu.replaceChildren();
        options.forEach((o) => {
            const opt = el('div', 'dd-opt' + (o.value === state.skill ? ' selected' : ''), o.label);
            // mousedown + preventDefault so the pick is never lost to a blur
            opt.addEventListener('mousedown', (e) => {
                e.preventDefault();
                state.skill = o.value;
                $('dd-skill-value').textContent = o.label;
                closeDd();
                setupSkillDd();
                loadBoard();
            });
            ddMenu.appendChild(opt);
        });
        const current = options.find((o) => o.value === state.skill) || options[0];
        $('dd-skill-value').textContent = current.label;
    }

    dd.addEventListener('mousedown', (e) => {
        if (e.target.closest('.dd-menu')) return;
        e.preventDefault();
        const open = !dd.classList.contains('open');
        dd.classList.toggle('open', open);
        ddMenu.classList.toggle('hidden', !open);
    });
    document.addEventListener('mousedown', (e) => {
        if (!e.target.closest('.dd')) closeDd();
    });

    /* ---------- leaderboard tab ---------- */
    function renderBoard(data) {
        const rows = $('board-rows');
        rows.replaceChildren();

        const showLevel = !!(data.top && data.top.length && data.top[0].level);
        $('col-level').textContent = showLevel ? L.colLevel : '';

        if (!data.top || !data.top.length) {
            rows.appendChild(el('div', 'empty', L.empty));
        } else {
            data.top.forEach((e) => {
                const row = el('div', 'row brow' + (e.me ? ' me' : '') + (e.rank === 1 ? ' top1' : ''));
                row.appendChild(el('span', 'c-rank', `#${e.rank}`));
                row.appendChild(el('span', 'c-name', e.name));
                row.appendChild(el('span', 'c-level', showLevel ? e.level : ''));
                row.appendChild(el('span', 'c-xp', fmt(e.xp)));
                rows.appendChild(row);
            });
        }

        const me = $('board-me');
        if (data.me && data.me.rank) {
            me.textContent = `${L.yourRank} #${data.me.rank} · ${fmt(data.me.xp)} ${L.xp}`;
        } else {
            me.textContent = `${L.unranked} · ${fmt(data.me ? data.me.xp : 0)} ${L.xp}`;
        }
    }

    async function loadBoard(retry = true) {
        const token = ++state.token;
        $('board-rows').replaceChildren(el('div', 'empty', L.loading));
        const data = await post('leaderboard', { mode: state.mode, skill: state.skill });
        if (token !== state.token) return; // a newer request replaced this one
        if (!data || !data.top) {
            // the server throttles quick repeats: try once more
            if (retry) { setTimeout(() => { if (token === state.token) loadBoard(false); }, 650); return; }
            renderBoard({ top: [], me: null });
            return;
        }
        state.weeklyEnabled = data.weeklyEnabled !== false;
        $('seg-mode').classList.toggle('hidden', !state.weeklyEnabled);
        renderBoard(data);
    }

    /* ---------- tabs / modes ---------- */
    function showTab(tab) {
        state.tab = tab;
        $('tab-skills').classList.toggle('active', tab === 'skills');
        $('tab-board').classList.toggle('active', tab === 'board');
        $('view-skills').classList.toggle('hidden', tab !== 'skills');
        $('view-board').classList.toggle('hidden', tab !== 'board');
        closeDd();
        if (tab === 'board') loadBoard();
    }

    function setMode(mode) {
        state.mode = mode;
        $('mode-all').classList.toggle('active', mode === 'all');
        $('mode-weekly').classList.toggle('active', mode === 'weekly');
        loadBoard();
    }

    $('tab-skills').addEventListener('click', () => showTab('skills'));
    $('tab-board').addEventListener('click', () => showTab('board'));
    $('mode-all').addEventListener('click', () => setMode('all'));
    $('mode-weekly').addEventListener('click', () => setMode('weekly'));

    /* ---------- open / close ---------- */
    function applyLabels() {
        $('title').textContent = L.title;
        $('subtitle').textContent = L.subtitle;
        $('btn-close').title = L.close;
        $('tab-skills').textContent = L.tabSkills;
        $('tab-board').textContent = L.tabBoard;
        $('sum-level-l').textContent = L.totalLevel;
        $('sum-xp-l').textContent = L.totalXP;
        $('mode-all').textContent = L.boardAll;
        $('mode-weekly').textContent = L.boardWeekly;
        $('col-rank').textContent = L.colRank;
        $('col-player').textContent = L.colPlayer;
        $('col-level').textContent = L.colLevel;
        $('col-xp').textContent = L.colXP;
    }

    function open(msg) {
        L = msg.labels || {};
        state.skills = (msg.data && msg.data.skills) || [];
        state.weeklyEnabled = msg.weeklyEnabled !== false;
        state.mode = 'all';
        state.skill = 'all';
        applyLabels();
        $('seg-mode').classList.toggle('hidden', !state.weeklyEnabled);
        $('mode-all').classList.add('active');
        $('mode-weekly').classList.remove('active');
        renderSkills(msg.data);
        setupSkillDd();
        showTab('skills');
        app.classList.remove('hidden');
    }

    function hide() {
        state.token++;
        closeDd();
        app.classList.add('hidden');
    }

    function requestClose() {
        hide();
        post('close');
    }

    $('btn-close').addEventListener('click', requestClose);
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && !app.classList.contains('hidden')) requestClose();
    });

    window.addEventListener('message', (e) => {
        const msg = e.data;
        if (!msg || !msg.action) return;
        if (msg.action === 'open') open(msg);
        else if (msg.action === 'close') hide();
    });
})();
