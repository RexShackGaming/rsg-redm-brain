'use strict';
// Plays through unsaved dialog entirely in the browser. Nothing is given, taken or saved.
const Preview = (() => {
    const $ = id => document.getElementById(id);
    const list = v => (Array.isArray(v) ? v : []);
    let def = null, L = {}, say = s => s;
    let node = null, flags = new Set(), used = new Set(), failing = new Set(), log = [];

    // flag rules are simulated; every other requirement passes unless "pretend fail" is on
    const flagsPass = r => !r || (list(r.flags).every(f => flags.has(f)) && !list(r.notFlags).some(f => flags.has(f)));

    function describe(block) {
        const out = [];
        Object.entries(block || {}).forEach(([key, value]) => {
            const items = Array.isArray(value) ? value : [value];
            items.forEach(v => out.push(key + ': ' + (typeof v === 'object' ? Object.values(v).join(' ') : v)));
        });
        return out.join(', ');
    }

    function start() {
        const alt = list(def.starts).find(s => def.nodes[s.node] && flagsPass(s.requires) && !failing.has('start:' + s.node));
        node = alt ? alt.node : def.start;
        log = [];
        render();
    }

    function restart() {
        flags = new Set();
        used = new Set();
        start();
    }

    function pick(c, key) {
        if (c.once) used.add(key);
        if (c.cost) log.push(L.preview_takes + ' ' + describe(c.cost));
        if (c.reward) log.push(L.preview_gives + ' ' + describe(c.reward));
        if (c.startQuest) log.push(L.start_quest + ': ' + c.startQuest);
        if (c.turnInQuest) log.push(L.turnin_quest + ': ' + c.turnInQuest);
        list(c.clearFlags).forEach(f => flags.delete(f));
        list(c.setFlags).forEach(f => flags.add(f));
        if (c.action) log.push(L.preview_action + ' ' + c.action);
        if (c.next && def.nodes[c.next]) node = c.next;
        else {
            node = null;
            log.push(L.preview_end);
        }
        render();
    }

    function render() {
        const current = node && def.nodes[node];
        $('pvName').textContent = say(def.name);
        $('pvText').textContent = current ? say(current.text) : L.preview_end;
        const replies = $('pvChoices');
        replies.textContent = '';
        let number = 0;
        list(current && current.choices).forEach((c, i) => {
            const key = node + ':' + (c.id || i);
            if (used.has(key)) return;
            const conditional = c.requires || c.turnInQuest || c.startQuest;
            const locked = !flagsPass(c.requires) || failing.has(key);
            const row = el('div', 'reply' + (locked ? ' locked' : ''));
            // hidden replies stay visible here (marked) so they can still be toggled back
            const why = locked ? (c.lock === 'show' ? L.lock_show : L.lock_hide) : describe(c.requires);
            row.append(el('span', 'num', ++number), el('span', 'reply-label', say(c.label)), el('span', 'reply-why', why));
            if (conditional) {
                const toggle = el('button', 'wood-btn fail-toggle ' + (failing.has(key) ? '' : 'muted'), L.pretend_fail);
                toggle.addEventListener('click', e => {
                    e.stopPropagation();
                    if (!failing.delete(key)) failing.add(key);
                    render();
                });
                row.append(toggle);
            }
            row.addEventListener('click', () => { if (!locked) pick(c, key); });
            replies.append(row);
        });
        $('pvFlags').textContent = Array.from(flags).join(', ') || L.none;
        const box = $('pvLog');
        box.textContent = '';
        log.forEach(line => box.append(el('div', null, line)));
        box.scrollTop = box.scrollHeight;
    }

    function open(draft, lang, translate) {
        def = draft;
        L = lang;
        say = translate;
        failing = new Set();
        $('pvTitle').textContent = L.preview;
        $('pvNote').textContent = L.preview_note;
        $('pvFlagsLabel').textContent = L.preview_flags;
        $('pvLogLabel').textContent = L.preview_log;
        const tools = $('pvTools');
        tools.textContent = '';
        const again = el('button', 'wood-btn', L.restart);
        again.addEventListener('click', restart);
        // "talk again" keeps flags, so alternative openings can be tested
        const talk = el('button', 'wood-btn muted', L.preview_again);
        talk.addEventListener('click', start);
        tools.append(again, talk);
        $('preview').classList.remove('hidden');
        restart();
    }

    const close = () => $('preview').classList.add('hidden');
    $('pvClose').addEventListener('click', close);
    return { open, close, isOpen: () => !$('preview').classList.contains('hidden') };
})();
