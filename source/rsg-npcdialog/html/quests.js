'use strict';
// Quest journal and on-screen tracker
(() => {
    const $ = id => document.getElementById(id);
    const root = $('journal'), tracker = $('tracker');
    const list = v => (Array.isArray(v) ? v : []);
    let data = {}, L = {}, tab = 'active', confirming = null;

    function objectives(q) {
        const box = el('div');
        list(q.objectives).forEach(o => {
            const row = el('div', 'obj' + (o.done ? ' done' : (o.open ? '' : ' later')));
            row.append(el('span', null, o.label), el('span', null, `${o.current}/${o.count}`));
            box.append(row);
        });
        return box;
    }

    function render() {
        const tabs = $('jTabs'), box = $('jList');
        const scroll = box.scrollTop; // progress updates must not jump the list back to the top
        tabs.textContent = '';
        box.textContent = '';
        ['active', 'completed'].forEach(t => {
            const b = el('button', 'wood-btn ' + (t === tab ? 'sel' : 'muted'), L[t]);
            b.addEventListener('click', () => { tab = t; confirming = null; $('jList').scrollTop = 0; render(); });
            tabs.append(b);
        });
        const quests = list(data[tab]);
        if (!quests.length) return box.append(el('div', 'note', L.empty));
        quests.forEach(q => {
            const card = el('div', 'card');
            const name = el('div', 'quest-name', q.name);
            if (q.reset) name.append(el('span', 'badge', q.reset));
            card.append(name);
            if (tab === 'completed') {
                card.append(el('div', 'quest-desc', `${L.times}: ${q.times}`));
            } else {
                if (q.description) card.append(el('div', 'quest-desc', q.description));
                card.append(objectives(q));
                if (q.ready) card.append(el('div', 'ready', L.ready));
                const actions = el('div', 'actions');
                if (confirming === q.id) {
                    const no = el('button', 'wood-btn muted', L.cancel), yes = el('button', 'wood-btn', L.confirm);
                    no.addEventListener('click', () => { confirming = null; render(); });
                    yes.addEventListener('click', () => { confirming = null; post('journalAbandon', { id: q.id }); });
                    actions.append(el('span', 'note', L.abandon_confirm), no, yes);
                } else {
                    const drop = el('button', 'wood-btn muted', L.abandon);
                    drop.addEventListener('click', () => { confirming = q.id; render(); });
                    const pin = el('button', 'wood-btn ' + (q.pinned ? 'sel' : 'muted'), q.pinned ? L.unpin : L.pin);
                    pin.addEventListener('click', () => post('journalPin', { id: q.id }));
                    const route = el('button', 'wood-btn ' + (q.routed ? 'sel' : 'muted'), q.routed ? L.route_stop : L.route);
                    route.disabled = !q.routed && !q.hasRoute;
                    route.addEventListener('click', () => post('journalRoute', { id: q.id }));
                    actions.append(pin, route, drop);
                }
                card.append(actions);
            }
            box.append(card);
        });
        box.scrollTop = scroll;
    }

    function drawTracker(m) {
        tracker.textContent = '';
        tracker.className = m.position === 'left' ? 'left' : 'right';
        const quests = list(m.quests).slice(0, Number(m.max) || 3);
        if (!m.visible || !quests.length) return tracker.classList.add('hidden');
        quests.forEach(q => {
            const card = el('div', 'card');
            card.append(el('div', 'quest-name', q.name), objectives(q));
            if (q.ready) card.append(el('div', 'ready', m.lang.ready));
            tracker.append(card);
        });
    }

    $('jClose').addEventListener('click', () => post('journalClose'));
    document.addEventListener('keyup', e => {
        if (e.key === 'Escape' && !root.classList.contains('hidden')) post('journalClose');
    });

    window.addEventListener('message', ({ data: m }) => {
        if (m.action === 'journalOpen') {
            L = m.lang || {};
            data = m.data || {};
            tab = 'active';
            confirming = null;
            $('jTitle').textContent = L.journal;
            $('jSubtitle').textContent = L.subtitle;
            root.classList.remove('hidden');
            render();
        } else if (m.action === 'journalData') {
            data = m.data || {};
            if (!root.classList.contains('hidden')) render();
        } else if (m.action === 'journalClose') root.classList.add('hidden');
        else if (m.action === 'tracker') drawTracker(m);
    });
})();
