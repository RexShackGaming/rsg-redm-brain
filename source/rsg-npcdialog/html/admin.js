'use strict';
// In-game editor. The server validates everything again on save.
(() => {
    const $ = id => document.getElementById(id);
    const root = $('editor'), form = $('eForm');
    let L = {}, defaults = {}, npcs = [], quests = [], actions = [], conditions = [], strings = {}, lookups = {};
    let mode = 'npc';
    const entries = () => (mode === 'npc' ? npcs : quests);
    // '@key' text is shown translated in lists and the preview
    const say = s => (typeof s === 'string' && strings[s]) || s || '';
    let draft = null, meta = null, tab = 'npc', node = null, dirty = false, saving = false, modalOk = null;

    const clone = o => JSON.parse(JSON.stringify(o));
    const arr = v => (Array.isArray(v) ? v : []);   // Lua sends empty tables as [] or {}
    const readonly = () => meta && meta.source !== 'db' && !meta.isNew;
    const nodeIds = () => Object.keys(draft.nodes).sort((a, b) => (b === draft.start) - (a === draft.start) || a.localeCompare(b));
    const changed = () => { dirty = true; };

    function toast(text, type) {
        const t = el('div', 'toast ' + (type || ''), text);
        $('toasts').append(t);
        setTimeout(() => t.remove(), 5000);
    }

    function confirmBox(text, onOk) {
        $('mText').textContent = text;
        $('mOk').textContent = L.confirm;
        $('mCancel').textContent = L.cancel;
        modalOk = onOk;
        $('modal').classList.remove('hidden');
    }
    const closeModal = () => { $('modal').classList.add('hidden'); modalOk = null; };
    const guard = fn => (dirty ? confirmBox(L.discard_confirm, () => { dirty = false; fn(); }) : fn());

    // ---------- widgets ----------
    const closeDropdowns = except => document.querySelectorAll('.dd.open').forEach(d => { if (d !== except) d.classList.remove('open'); });
    document.addEventListener('mousedown', e => closeDropdowns(e.target.closest('.dd')));

    function dropdown(options, value, onChange, disabled) {
        const dd = el('div', 'dd' + (disabled ? ' disabled' : ''));
        const label = el('span', 'dd-value'), menu = el('div', 'dd-menu');
        const current = options.find(o => o[0] === value);
        label.textContent = current ? current[1] : (value || '');
        options.forEach(([v, text]) => {
            const opt = el('div', 'dd-opt' + (v === value ? ' sel' : ''), text);
            opt.addEventListener('mousedown', e => {
                e.preventDefault();
                e.stopPropagation();
                dd.classList.remove('open');
                value = v;
                label.textContent = text;
                menu.querySelectorAll('.dd-opt').forEach(o => o.classList.toggle('sel', o === opt));
                onChange(v);
            });
            menu.append(opt);
        });
        dd.append(label, el('span', 'dd-arrow', '▾'), menu);
        dd.addEventListener('mousedown', () => { if (!disabled) dd.classList.toggle('open'); });
        return dd;
    }

    // searchable dropdown that still accepts typed values (the server checks them on save)
    function combo(value, options, onChange, placeholder) {
        const wrap = el('div', 'combo'), menu = el('div', 'dd-menu');
        const field = input(value, v => { onChange(v.trim()); open(v); }, { placeholder });
        function open(filter) {
            if (field.disabled) return;
            menu.textContent = '';
            const q = String(filter || '').toLowerCase();
            const list = (typeof options === 'function' ? options() : options || [])
                .filter(o => (o[0] + ' ' + say(o[1])).toLowerCase().includes(q)).slice(0, 60);
            list.forEach(([v, label]) => {
                const opt = el('div', 'dd-opt', v);
                if (say(label) !== v) opt.append(el('small', null, say(label)));
                opt.addEventListener('mousedown', e => {
                    e.preventDefault();
                    field.value = v;
                    onChange(v);
                    changed();
                    wrap.classList.remove('open');
                });
                menu.append(opt);
            });
            wrap.classList.toggle('open', list.length > 0);
            if (list.length) menu.scrollIntoView({ block: 'nearest' });
        }
        field.addEventListener('focus', () => open(''));
        field.addEventListener('click', () => open(''));
        field.addEventListener('blur', () => wrap.classList.remove('open'));
        menu.addEventListener('mousedown', e => e.preventDefault()); // keeps the list open while scrolling it
        wrap.append(field, menu);
        return wrap;
    }

    const lookup = kind => () => {
        if (kind === 'quest') return quests.map(q => [q.def.id, q.def.name]);
        if (kind === 'custom') return conditions;
        if (kind === 'npc') return npcs.map(n => [n.def.id, n.def.name]);
        return arr(lookups[kind]);
    };

    function input(value, onInput, opts = {}) {
        const n = el(opts.area ? 'textarea' : 'input', 'field');
        n.value = value === undefined || value === null ? '' : value;
        n.maxLength = opts.max || 100;
        if (opts.placeholder) n.placeholder = opts.placeholder;
        n.disabled = readonly();
        n.addEventListener('input', () => { onInput(n.value); changed(); });
        return n;
    }

    function labelled(text, control, wide) {
        const w = el('div', wide ? 'wide' : '');
        w.append(el('span', 'label', text), control);
        return w;
    }

    function checkbox(text, value, onChange) {
        const w = el('div', 'check'), box = el('span', 'box', value ? '✓' : '');
        w.append(box, el('span', null, text));
        w.addEventListener('click', () => {
            if (readonly()) return;
            value = !value;
            box.textContent = value ? '✓' : '';
            onChange(value);
            changed();
        });
        return w;
    }

    function button(text, onClick, cls, always) {
        const b = el('button', 'wood-btn ' + (cls || ''), text);
        b.disabled = !always && readonly();
        b.addEventListener('click', onClick);
        return b;
    }

    // ---------- rule rows (requirements, costs, rewards) ----------
    // each type: [label key, [field names]]
    const MONEY = ['cash', 'bank', 'gold', 'bloodmoney'];
    const STATES = ['available', 'active', 'ready', 'completed', 'notcompleted'];
    const SOURCES = { job: 'job', anyjob: 'job', gang: 'gang', item: 'item', skill: 'skill', skillxp: 'skill',
        standing: 'region', custom: 'custom', quest: 'quest', weather: 'weather' };
    const RULES = {
        requires: { quest: ['quest_state', ['key', 'state']], anyjob: ['anyjob', ['key', 'amount']], job: ['job', ['key', 'amount']], gang: ['gang', ['key', 'amount']], onduty: ['onduty', []],
            item: ['item', ['key', 'amount']], money: ['money', ['money', 'amount']], flag: ['flag', ['key']],
            notflag: ['notflag', ['key']], skill: ['skill', ['key', 'amount']], honor: ['honor', ['min', 'max']],
            standing: ['standing', ['key', 'min', 'max']], custom: ['custom', ['key', 'arg']],
            time: ['time', ['from', 'to']], weather: ['weather', ['key']] },
        cost: { item: ['item', ['key', 'amount']], money: ['money', ['money', 'amount']] },
        reward: { item: ['item', ['key', 'amount']], money: ['money', ['money', 'amount']], skillxp: ['skillxp', ['key', 'amount']],
            honor: ['honor', ['amount']], standing: ['standing', ['key', 'amount']] },
    };

    function toRows(kind, o) {
        const rows = [];
        if (!o) return rows;
        arr(o.items).forEach(i => rows.push({ type: 'item', key: i.name, amount: i.amount }));
        arr(o.money).forEach(m => rows.push({ type: 'money', money: m.type, amount: m.amount }));
        if (kind === 'requires') {
            [['job', 'job'], ['gang', 'gang'], ['anyjob', 'anyJob']].forEach(([t, k]) =>
                Object.entries(o[k] || {}).forEach(([name, v]) => rows.push({ type: t, key: name, amount: v })));
            arr(o.quests).forEach(q => rows.push({ type: 'quest', key: q.id, state: q.state }));
            if (o.onduty) rows.push({ type: 'onduty' });
            arr(o.flags).forEach(f => rows.push({ type: 'flag', key: f }));
            arr(o.notFlags).forEach(f => rows.push({ type: 'notflag', key: f }));
            arr(o.skills).forEach(s => rows.push({ type: 'skill', key: s.skill, amount: s.level }));
            if (o.honor) rows.push({ type: 'honor', min: o.honor.min, max: o.honor.max });
            arr(o.standing).forEach(s => rows.push({ type: 'standing', key: s.region, min: s.min, max: s.max }));
            arr(o.custom).forEach(c => rows.push({ type: 'custom', key: c.name, arg: c.arg }));
            if (o.time) rows.push({ type: 'time', from: o.time.from, to: o.time.to });
            arr(o.weather).forEach(w => rows.push({ type: 'weather', key: w }));
        }
        if (kind === 'reward') {
            arr(o.skillXP).forEach(s => rows.push({ type: 'skillxp', key: s.skill, amount: s.amount }));
            if (o.honor !== undefined) rows.push({ type: 'honor', amount: o.honor });
            arr(o.standing).forEach(s => rows.push({ type: 'standing', key: s.region, amount: s.amount }));
        }
        return rows;
    }

    function fromRows(kind, rows) {
        const o = {};
        const push = (k, v) => (o[k] = o[k] || []).push(v);
        const num = v => (v === undefined || v === null || String(v).trim() === '' ? undefined : (isNaN(Number(v)) ? v : Number(v)));
        const word = v => String(v || '').trim();
        rows.forEach(r => {
            const key = word(r.key), amount = num(r.amount);
            if (r.type === 'item') push('items', { name: key, amount });
            else if (r.type === 'money') push('money', { type: r.money || 'cash', amount });
            else if (r.type === 'job' || r.type === 'gang') (o[r.type] = o[r.type] || {})[key] = amount || 0;
            else if (r.type === 'anyjob') (o.anyJob = o.anyJob || {})[key] = amount || 0;
            else if (r.type === 'quest') push('quests', { id: key, state: r.state || 'available' });
            else if (r.type === 'onduty') o.onduty = true;
            else if (r.type === 'flag') push('flags', key);
            else if (r.type === 'notflag') push('notFlags', key);
            else if (r.type === 'skill') push('skills', { skill: key, level: amount });
            else if (r.type === 'skillxp') push('skillXP', { skill: key, amount });
            else if (r.type === 'time') o.time = { from: num(r.from), to: num(r.to) };
            else if (r.type === 'weather') push('weather', key);
            else if (r.type === 'custom') push('custom', { name: key, arg: word(r.arg) });
            else if (r.type === 'honor') o.honor = kind === 'requires' ? { min: num(r.min), max: num(r.max) } : amount;
            else if (r.type === 'standing') push('standing', kind === 'requires'
                ? { region: key, min: num(r.min), max: num(r.max) } : { region: key, amount });
        });
        return Object.keys(o).length ? o : undefined;
    }

    // rows live on the object as _<kind> while editing, and are converted back on save
    function ruleEditor(owner, kind, title) {
        const slot = '_' + kind;
        if (!owner[slot]) owner[slot] = toRows(kind, owner[kind]);
        const rows = owner[slot], wrap = el('div');
        const head = el('div', 'card-head');
        head.append(el('span', 'section', title), button('+ ' + L.add, () => {
            rows.push({ type: 'item' });
            changed();
            render();
        }, 'muted'));
        wrap.append(head);
        rows.forEach((r, i) => {
            const line = el('div', 'rule');
            line.append(dropdown(Object.entries(RULES[kind]).map(([v, d]) => [v, L[d[0]]]), r.type, v => {
                rows[i] = { type: v };
                changed();
                render();
            }, readonly()));
            const fields = RULES[kind][r.type][1];
            for (let f = 0; f < 3; f++) {
                const name = fields[f];
                if (!name) line.append(el('span'));
                else if (name === 'money') {
                    if (!r.money) r.money = 'cash';
                    line.append(dropdown(MONEY.map(m => [m, m]), r.money, v => { r.money = v; changed(); }, readonly()));
                } else if (name === 'state') {
                    if (!r.state) r.state = 'available';
                    line.append(dropdown(STATES.map(v => [v, L['st_' + v]]), r.state, v => { r.state = v; changed(); }, readonly()));
                } else if (name === 'key' && SOURCES[r.type]) {
                    line.append(combo(r.key, lookup(SOURCES[r.type]), v => { r.key = v; }, L.key));
                } else line.append(input(r[name], v => { r[name] = v; }, { placeholder: L[name] || name }));
            }
            line.append(button('✕', () => { rows.splice(i, 1); changed(); render(); }, 'muted'));
            wrap.append(line);
        });
        return wrap;
    }

    function serialise(def) {
        const d = clone(def);
        const apply = (o, kind) => {
            if (!o['_' + kind]) return;
            const v = fromRows(kind, o['_' + kind]);
            if (v) o[kind] = v; else delete o[kind];
            delete o['_' + kind];
        };
        const words = (o, key) => {
            const slot = '_' + key;
            if (o[slot] === undefined) return;
            o[key] = o[slot].split(',').map(s => s.trim()).filter(Boolean);
            delete o[slot];
        };
        apply(d, 'requires');
        if (mode === 'quest') {
            apply(d, 'reward');
            d.objectives.forEach(o => {
                if (o._models !== undefined) {
                    o.models = o._models.split(',').map(s => s.trim()).filter(Boolean);
                    delete o._models;
                }
                ['node', 'choice'].forEach(k => { if (o[k] === '') delete o[k]; });
            });
            if (d.description === '') delete d.description;
            ['reset', 'pool'].forEach(k => { if (d[k] === '') delete d[k]; });
            return d;
        }
        d.starts = arr(d.starts);
        d.starts.forEach(s => apply(s, 'requires'));
        Object.values(d.nodes).forEach(n => {
            n.choices = arr(n.choices);
            n.choices.forEach(c => {
                ['requires', 'cost', 'reward'].forEach(k => apply(c, k));
                words(c, 'setFlags');
                words(c, 'clearFlags');
                ['id', 'next', 'action', 'cooldown', 'startQuest', 'turnInQuest'].forEach(k => { if (c[k] === '') delete c[k]; });
            });
        });
        if (d.scenario === '') delete d.scenario;
        d.schedule = arr(d.schedule);
        d.schedule.forEach(s => { if (!s.scenario) delete s.scenario; });
        if (!d.schedule.length) delete d.schedule;
        if (d.title === '') delete d.title;
        return d;
    }

    // ---------- tabs ----------
    function npcTab() {
        const g = el('div', 'grid');
        const idField = input(draft.id, v => { draft.id = v.trim(); }, { max: 50 });
        idField.disabled = !meta.isNew;
        draft.blip = draft.blip || { enabled: false };
        g.append(
            labelled(L.id, idField), labelled(L.model, input(draft.model, v => { draft.model = v.trim(); }, { max: 50 })),
            labelled(L.name, input(draft.name, v => { draft.name = v; })), labelled(L.npc_title, input(draft.title, v => { draft.title = v; })),
            labelled(L.scenario, input(draft.scenario, v => { draft.scenario = v.trim(); }, { max: 50 })),
            labelled(L.distance, input(draft.distance, v => { draft.distance = v; }, { max: 5 })),
            checkbox(L.enabled, draft.enabled !== false, v => { draft.enabled = v; }),
            checkbox(L.blip, !!draft.blip.enabled, v => { draft.blip.enabled = v; }),
            labelled(L.blip_sprite, input(draft.blip.sprite || 'blip_ambient_npc', v => { draft.blip.sprite = v.trim(); }, { max: 50 }), true),
        );
        form.append(g, el('div', 'section', L.coords));

        const coords = el('div', 'grid');
        ['x', 'y', 'z', 'w'].forEach(k => coords.append(labelled(k.toUpperCase(),
            input(draft.coords ? draft.coords[k] : '', v => { draft.coords = draft.coords || { x: 0, y: 0, z: 0, w: 0 }; draft.coords[k] = v; }, { max: 12 }))));
        const tools = el('div', 'inline');
        tools.append(
            button(L.place, () => post('editorPlace', { model: draft.model, coords: numericCoords() })),
            button(L.here, async () => {
                const c = await post('editorHere');
                if (c) { draft.coords = c; changed(); render(); }
            }),
            button(L.teleport, () => { const c = numericCoords(); if (c) post('editorTeleport', { coords: c }); }, 'muted', true),
        );
        form.append(coords, tools);
        scheduleEditor();
        form.append(ruleEditor(draft, 'requires', L.npc_requires));
    }

    // opening hours: each time slot may have its own spot and scenario
    function scheduleEditor() {
        draft.schedule = arr(draft.schedule);
        const head = el('div', 'card-head');
        const add = button('+ ' + L.add_slot, () => {
            draft.schedule.push({ from: 8, to: 20 });
            changed();
            render();
        }, 'muted');
        add.disabled = readonly() || draft.schedule.length >= 8;
        head.append(el('span', 'section', L.schedule), add);
        form.append(head, el('div', 'note', L.schedule_note));

        draft.schedule.forEach((s, i) => {
            const card = el('div', 'card'), h = el('div', 'card-head'), g = el('div', 'grid');
            h.append(el('span', 'num', i + 1), button('✕', () => { draft.schedule.splice(i, 1); changed(); render(); }, 'muted'));
            g.append(
                labelled(L.from, input(s.from, v => { s.from = v; }, { max: 2 })),
                labelled(L.to, input(s.to, v => { s.to = v; }, { max: 2 })),
                labelled(L.scenario, input(s.scenario, v => { s.scenario = v.trim(); }, { max: 50 }), true),
                checkbox(L.own_position, !!s.coords, v => {
                    if (v) s.coords = clone(draft.coords || { x: 0, y: 0, z: 0, w: 0 });
                    else delete s.coords;
                    render();
                }),
            );
            card.append(h, g);
            if (s.coords) {
                const c = el('div', 'grid');
                ['x', 'y', 'z', 'w'].forEach(k => c.append(labelled(k.toUpperCase(),
                    input(s.coords[k], v => { s.coords[k] = v; }, { max: 12 }))));
                const tools = el('div', 'inline');
                tools.append(
                    button(L.place, () => post('editorPlace', { model: draft.model, coords: numericCoords(s.coords), slot: i })),
                    button(L.here, async () => {
                        const p = await post('editorHere');
                        if (p) { s.coords = p; changed(); render(); }
                    }),
                    button(L.teleport, () => { const p = numericCoords(s.coords); if (p) post('editorTeleport', { coords: p }); }, 'muted', true),
                );
                card.append(c, tools);
            }
            form.append(card);
        });
    }

    function numericCoords(source = draft.coords) {
        if (!source) return null;
        const c = {};
        for (const k of ['x', 'y', 'z', 'w']) {
            c[k] = Number(source[k]);
            if (isNaN(c[k])) return null;
        }
        return c;
    }

    function nodeOptions(withEnd) {
        const list = nodeIds().map(n => [n, n]);
        return withEnd ? [['', L.end], ...list] : list;
    }

    const references = id => draft.start === id || arr(draft.starts).some(s => s.node === id)
        || Object.entries(draft.nodes).some(([k, n]) => k !== id && arr(n.choices).some(c => c.next === id));

    function renameNode(from, to) {
        if (to === from) return;
        if (!/^[\w-]{1,50}$/.test(to) || Object.prototype.hasOwnProperty.call(draft.nodes, to)) return toast(L.bad_node_id, 'error');
        draft.nodes[to] = draft.nodes[from];
        delete draft.nodes[from];
        if (draft.start === from) draft.start = to;
        arr(draft.starts).forEach(s => { if (s.node === from) s.node = to; });
        Object.values(draft.nodes).forEach(n => arr(n.choices).forEach(c => { if (c.next === from) c.next = to; }));
        node = to;
        changed();
        render();
    }

    function dialogTab() {
        const top = el('div', 'grid');
        top.append(labelled(L.start, dropdown(nodeOptions(), draft.start, v => { draft.start = v; changed(); }, readonly())));
        form.append(top);

        draft.starts = arr(draft.starts);
        const head = el('div', 'card-head');
        head.append(el('span', 'section', L.starts), button('+ ' + L.add_start, () => {
            draft.starts.push({ node: draft.start });
            changed();
            render();
        }, 'muted'));
        form.append(head);
        draft.starts.forEach((s, i) => {
            const card = el('div', 'card'), h = el('div', 'card-head');
            h.append(dropdown(nodeOptions(), s.node, v => { s.node = v; changed(); }, readonly()),
                button(L.remove, () => { draft.starts.splice(i, 1); changed(); render(); }, 'muted'));
            card.append(h, ruleEditor(s, 'requires', L.requires));
            form.append(card);
        });

        form.append(el('div', 'section', L.nodes));
        if (!draft.nodes[node]) node = nodeIds()[0];
        const strip = el('div', 'nodes');
        nodeIds().forEach(id => strip.append(button(id, () => { node = id; render(); }, id === node ? 'sel' : 'muted', true)));
        strip.append(button('+ ' + L.add_node, () => {
            let n = 1;
            while (draft.nodes['node' + n]) n++;
            node = 'node' + n;
            draft.nodes[node] = { text: '', choices: [] };
            changed();
            render();
        }));
        form.append(strip);

        const cur = draft.nodes[node];
        cur.choices = arr(cur.choices);
        let newId = node;
        const rename = el('div', 'inline');
        rename.append(input(node, v => { newId = v.trim(); }, { max: 50 }), button(L.rename, () => renameNode(node, newId), 'muted'),
            button(L.delete, () => {
                if (references(node)) return toast(L.node_in_use, 'error');
                delete draft.nodes[node];
                node = null;
                changed();
                render();
            }, 'muted'));
        rename.firstChild.style.width = '220px';
        form.append(labelled(L.node_id, rename), labelled(L.node_text, input(cur.text, v => { cur.text = v; }, { area: true, max: 2000 })));

        const ch = el('div', 'card-head');
        const add = button('+ ' + L.add_choice, () => {
            let n = 1;
            while (cur.choices.some(c => c.id === 'c' + n)) n++;
            cur.choices.push({ id: 'c' + n, label: '', lock: 'hide' });
            changed();
            render();
        });
        add.disabled = readonly() || cur.choices.length >= 9;
        ch.append(el('span', 'section', L.choices), add);
        form.append(ch);
        cur.choices.forEach((c, i) => form.append(choiceCard(cur, c, i)));
    }

    function choiceCard(cur, c, i) {
        const card = el('div', 'card'), g = el('div', 'grid');
        const head = el('div', 'card-head'), tools = el('div', 'inline');
        const move = d => { const j = i + d; if (cur.choices[j]) { [cur.choices[i], cur.choices[j]] = [cur.choices[j], c]; changed(); render(); } };
        tools.append(button('▲', () => move(-1), 'muted'), button('▼', () => move(1), 'muted'),
            button('✕', () => { cur.choices.splice(i, 1); changed(); render(); }, 'muted'));
        head.append(el('span', 'num', i + 1), tools);

        if (c._setFlags === undefined) c._setFlags = arr(c.setFlags).join(', ');
        if (c._clearFlags === undefined) c._clearFlags = arr(c.clearFlags).join(', ');
        const actionList = [['', L.none], ...actions.map(a => [a, a])];

        g.append(
            labelled(L.choice_text, input(c.label, v => { c.label = v; }, { max: 300 }), true),
            labelled(L.choice_id, input(c.id, v => { c.id = v.trim(); }, { max: 50 })),
            labelled(L.next, dropdown(nodeOptions(true), c.next || '', v => { c.next = v; changed(); }, readonly())),
            labelled(L.lock, dropdown([['hide', L.lock_hide], ['show', L.lock_show]], c.lock || 'hide', v => { c.lock = v; changed(); }, readonly())),
            labelled(L.action, dropdown(actionList, c.action || '', v => { c.action = v; changed(); }, readonly())),
            checkbox(L.once, !!c.once, v => { c.once = v; }),
            checkbox(L.repeatable, !!c.repeatable, v => { c.repeatable = v; }),
            labelled(L.cooldown, input(c.cooldown, v => { c.cooldown = v; }, { max: 9 })),
            el('span'),
            labelled(L.start_quest, combo(c.startQuest, lookup('quest'), v => { c.startQuest = v; }, L.type_search)),
            labelled(L.turnin_quest, combo(c.turnInQuest, lookup('quest'), v => { c.turnInQuest = v; }, L.type_search)),
            labelled(L.set_flags, input(c._setFlags, v => { c._setFlags = v; }, { max: 300, placeholder: L.comma })),
            labelled(L.clear_flags, input(c._clearFlags, v => { c._clearFlags = v; }, { max: 300, placeholder: L.comma })),
        );
        card.append(head, g, ruleEditor(c, 'requires', L.requires), ruleEditor(c, 'cost', L.cost), ruleEditor(c, 'reward', L.reward));
        return card;
    }

    // ---------- quest form ----------
    const OBJ_TYPES = ['deliver', 'visit', 'talk', 'kill', 'custom'];

    function objectiveCard(o, i) {
        const card = el('div', 'card'), g = el('div', 'grid');
        const head = el('div', 'card-head'), tools = el('div', 'inline');
        const list = draft.objectives;
        const move = d => { const j = i + d; if (list[j]) { [list[i], list[j]] = [list[j], o]; changed(); render(); } };
        tools.append(button('▲', () => move(-1), 'muted'), button('▼', () => move(1), 'muted'),
            button('✕', () => { list.splice(i, 1); changed(); render(); }, 'muted'));
        head.append(el('span', 'num', i + 1), tools);
        g.append(
            labelled(L.obj_type, dropdown(OBJ_TYPES.map(t => [t, L['obj_' + t]]), o.type, v => {
                list[i] = { id: o.id, label: o.label, type: v, count: 1 };
                changed();
                render();
            }, readonly())),
            labelled(L.id, input(o.id, v => { o.id = v.trim(); }, { max: 50 })),
            labelled(L.obj_label, input(o.label, v => { o.label = v; }, { max: 200 }), true),
        );
        if (o.type !== 'visit' && o.type !== 'talk') g.append(labelled(L.count, input(o.count, v => { o.count = v; }, { max: 5 })));
        if (o.type === 'deliver') g.append(labelled(L.item, combo(o.item, lookup('item'), v => { o.item = v; }, L.type_search)));
        if (o.type === 'kill') {
            if (o._models === undefined) o._models = arr(o.models).join(', ');
            g.append(labelled(L.models, input(o._models, v => { o._models = v; }, { max: 600, placeholder: L.comma }), true));
        }
        if (o.type === 'talk') {
            const npc = () => npcs.find(n => n.def.id === o.npc);
            const lines = () => Object.keys(npc() ? npc().def.nodes : {}).sort().map(k => [k, k]);
            const replies = () => {
                const n = npc() && npc().def.nodes[o.node];
                return arr(n && n.choices).map(c => [c.id, say(c.label)]);
            };
            g.append(
                labelled(L.target_npc, combo(o.npc, lookup('npc'), v => { o.npc = v; }, L.type_search)),
                labelled(L.target_line, combo(o.node, lines, v => { o.node = v; }, L.any)),
                labelled(L.target_reply, combo(o.choice, replies, v => { o.choice = v; }, L.any)),
            );
        }
        card.append(head, g);
        if (o.type === 'visit') {
            o.coords = o.coords || { x: '', y: '', z: '' };
            const c = el('div', 'grid');
            ['x', 'y', 'z'].forEach(k => c.append(labelled(k.toUpperCase(), input(o.coords[k], v => { o.coords[k] = v; }, { max: 12 }))));
            c.append(labelled(L.radius, input(o.radius === undefined ? 5 : o.radius, v => { o.radius = v; }, { max: 6 })),
                checkbox(L.show_blip, o.blip !== false, v => { o.blip = v; }));
            card.append(c, button(L.here, async () => {
                const p = await post('editorHere');
                if (p) { o.coords = { x: p.x, y: p.y, z: p.z }; changed(); render(); }
            }));
        }
        return card;
    }

    function questForm() {
        const g = el('div', 'grid');
        const idField = input(draft.id, v => { draft.id = v.trim(); }, { max: 50 });
        idField.disabled = !meta.isNew;
        g.append(
            labelled(L.id, idField), labelled(L.name, input(draft.name, v => { draft.name = v; })),
            labelled(L.description, input(draft.description, v => { draft.description = v; }, { area: true, max: 1000 }), true),
            checkbox(L.enabled, draft.enabled !== false, v => { draft.enabled = v; }),
            checkbox(L.ordered, !!draft.ordered, v => { draft.ordered = v; }),
            checkbox(L.auto_complete, !!draft.autoComplete, v => { draft.autoComplete = v; }),
            checkbox(L.quest_repeatable, !!draft.repeatable, v => { draft.repeatable = v; }),
            // daily and weekly quests use the reset time instead of a cooldown
            draft.reset ? el('span') : labelled(L.cooldown, input(draft.cooldown, v => { draft.cooldown = v; }, { max: 9 })),
            labelled(L.reset, dropdown([['', L.none], ['daily', L.reset_daily], ['weekly', L.reset_weekly]], draft.reset || '', v => {
                draft.reset = v;
                if (v) draft.repeatable = true;
                changed();
                render();
            }, readonly())),
            labelled(L.pool, input(draft.pool, v => { draft.pool = v.trim(); }, { max: 50 })),
        );
        draft.objectives = arr(draft.objectives);
        const head = el('div', 'card-head');
        const add = button('+ ' + L.add_objective, () => {
            let n = 1;
            while (draft.objectives.some(o => o.id === 'o' + n)) n++;
            draft.objectives.push({ id: 'o' + n, type: 'deliver', label: '', count: 1 });
            changed();
            render();
        });
        add.disabled = readonly() || draft.objectives.length >= 10;
        head.append(el('span', 'section', L.objectives), add);
        form.append(g, head);
        draft.objectives.forEach((o, i) => form.append(objectiveCard(o, i)));
        form.append(ruleEditor(draft, 'requires', L.requires), ruleEditor(draft, 'reward', L.quest_rewards));
    }

    // ---------- frame ----------
    function renderList() {
        const q = $('eSearch').value.toLowerCase(), list = $('eList');
        list.textContent = '';
        $('eModes').textContent = '';
        [['npc', L.npcs], ['quest', L.quests]].forEach(([m, label]) => $('eModes').append(button(label, () => {
            if (m === mode) return;
            guard(() => { mode = m; draft = meta = null; tab = 'npc'; $('eSearch').value = ''; render(); });
        }, m === mode ? 'sel' : 'muted', true)));
        $('eNew').textContent = '+ ' + (mode === 'npc' ? L.new : L.new_quest);
        entries().filter(n => (n.def.id + ' ' + say(n.def.name)).toLowerCase().includes(q)).forEach(n => {
            const row = el('div', 'row' + (meta && !meta.isNew && meta.id === n.def.id ? ' sel' : ''));
            const sub = el('div', 'row-sub');
            sub.append(el('span', null, n.def.id), el('span', 'badge', n.source));
            row.append(el('div', 'row-name', say(n.def.name)), sub);
            row.addEventListener('click', () => guard(() => select(n)));
            list.append(row);
        });
    }

    function render() {
        const scroll = form.scrollTop;
        renderList();
        form.textContent = '';
        $('eTabs').textContent = '';
        $('eActions').textContent = '';
        if (!draft) return form.append(el('div', 'note', mode === 'npc' ? L.select : L.select_quest));

        if (mode === 'npc') {
            ['npc', 'dialog'].forEach(t => $('eTabs').append(button(L[t], () => { tab = t; form.scrollTop = 0; render(); }, tab === t ? 'sel' : 'muted', true)));
        }
        if (readonly()) form.append(el('div', 'note', L.readonly));
        if (mode === 'quest') questForm(); else if (tab === 'npc') npcTab(); else dialogTab();
        form.scrollTop = scroll;

        if (mode === 'npc') {
            // plays through the unsaved form in the browser only: nothing is sent to the server
            $('eActions').append(button(L.preview, () => Preview.open(serialise(draft), L, say), 'muted', true));
        }
        if (!meta.isNew) {
            $('eActions').append(button(L.copy, () => guard(() => {
                const src = entries().find(n => n.def.id === meta.id);
                const def = clone(src.def);
                def.id = (def.id + '_copy').slice(0, 50);
                select({ def, source: 'db' }, true);
                dirty = true;
            }), 'muted', true));
        }
        if (meta.source === 'db' && !meta.isNew) {
            $('eActions').append(button(L.delete, () => confirmBox(L.delete_confirm, async () => {
                const r = await post('editorDelete', { kind: mode, id: meta.id });
                if (!r || !r.ok) return toast(r && r.error, 'error');
                load(r.data);
                draft = meta = null;
                dirty = false;
                toast(L.deleted, 'success');
                render();
            }), 'muted'));
        }
        if (!readonly()) $('eActions').append(button(L.save, save));
    }

    async function save() {
        if (saving) return;
        saving = true;
        const def = serialise(draft), isNew = meta.isNew, kind = mode;
        const r = await post('editorSave', { kind, payload: JSON.stringify(def), isNew });
        saving = false;
        if (!r || !r.ok) return toast(r && r.error, 'error');
        load(r.data);
        dirty = false;
        toast(L.saved, 'success');
        if (kind === mode) select(entries().find(n => n.def.id === r.id));
    }

    function select(entry, isNew) {
        if (!entry) return;
        draft = clone(entry.def);
        meta = { id: draft.id, source: entry.source, isNew: !!isNew };
        node = draft.start || null;
        form.scrollTop = 0;
        render();
    }

    function load(data) {
        npcs = arr(data.npcs);
        quests = arr(data.quests);
        actions = arr(data.actions);
        conditions = arr(data.conditions);
        strings = data.strings && !Array.isArray(data.strings) ? data.strings : {};
        if (data.lookups) lookups = data.lookups;
    }

    function newEntry() {
        if (mode === 'quest') {
            select({ source: 'db', def: {
                id: '', name: '', description: '', enabled: true,
                objectives: [{ id: 'o1', type: 'deliver', label: '', count: 1 }],
            } }, true);
            dirty = true;
            return render();
        }
        select({ source: 'db', def: {
            id: '', name: '', title: '', model: 'u_m_m_valgenstoreowner_01', scenario: '', enabled: true,
            distance: defaults.distance, start: 'start',
            nodes: { start: { text: '', choices: [{ id: 'bye', label: '', lock: 'hide' }] } },
        } }, true);
        tab = 'npc';
        dirty = true;
        render();
    }

    function requestClose() { guard(() => { root.classList.add('hidden'); closeDropdowns(); post('editorClose'); }); }

    $('eClose').addEventListener('click', requestClose);
    $('eNew').addEventListener('click', () => guard(newEntry));
    $('eSearch').addEventListener('input', renderList);
    $('mCancel').addEventListener('click', closeModal);
    $('mOk').addEventListener('click', () => { const fn = modalOk; closeModal(); if (fn) fn(); });
    document.addEventListener('keyup', e => {
        if (e.key !== 'Escape' || root.classList.contains('hidden')) return;
        if (!$('modal').classList.contains('hidden')) closeModal();
        else if (Preview.isOpen()) Preview.close();
        else if (document.querySelector('.dd.open')) closeDropdowns();
        else requestClose();
    });

    window.addEventListener('message', ({ data }) => {
        if (data.action === 'editorOpen') {
            L = data.lang || {};
            defaults = data.defaults || {};
            load(data.data);
            $('eTitle').textContent = L.title;
            $('eSubtitle').textContent = L.subtitle;
            $('eSearch').placeholder = L.search;
            if (!dirty) { // unsaved work (after a teleport) is kept
                const again = meta && !meta.isNew && entries().find(n => n.def.id === meta.id);
                draft = meta = null;
                if (again) select(again);
            }
            closeModal();
            Preview.close();
            root.classList.remove('hidden');
            render();
        } else if (data.action === 'editorHide') {
            closeDropdowns();
            root.classList.add('hidden');
        } else if (data.action === 'editorResume') {
            root.classList.remove('hidden');
            if (data.coords && draft) {
                const slot = typeof data.slot === 'number' ? arr(draft.schedule)[data.slot] : null;
                if (slot) slot.coords = data.coords; else draft.coords = data.coords;
                dirty = true;
            }
            render();
        } else if (data.action === 'editorClose') {
            closeModal();
            Preview.close();
            root.classList.add('hidden');
        }
    });
})();
